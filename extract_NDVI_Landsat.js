// Set the area of interest (AOI)
var AOI = geometry;

// Function to scale and mask Landsat 8 (C2) surface reflectance images.
function prepSrL8(image) {
  // Develop masks for unwanted pixels (fill, cloud, cloud shadow).
  var qaMask = image.select('QA_PIXEL').bitwiseAnd(parseInt('11111', 2)).eq(0);
  var saturationMask = image.select('QA_RADSAT').eq(0);

  // Function to get scaling factors for the appropriate bands.
  var getFactorImg = function(factorNames) {
    var factorList = image.toDictionary().select(factorNames).values();
    return ee.Image.constant(factorList);
  };

  // Apply scaling factors to reflectance and temperature bands.
  var scaleImg = getFactorImg([
    'REFLECTANCE_MULT_BAND_.|TEMPERATURE_MULT_BAND_ST_B10'
  ]);
  var offsetImg = getFactorImg([
    'REFLECTANCE_ADD_BAND_.|TEMPERATURE_ADD_BAND_ST_B10'
  ]);

  // Scale the bands and apply the masks.
  var scaled = image.select('SR_B.|ST_B10').multiply(scaleImg).add(offsetImg);
  return image.addBands(scaled, null, true)
               .updateMask(qaMask)
               .updateMask(saturationMask);
}

// Function to calculate NDVI and add it as a band.
var addNDVI = function(image) {
  var ndvi = image.normalizedDifference(['SR_B5', 'SR_B4']).rename('SR_NDVI').toDouble();
  return image.addBands(ndvi);
};

// Filter Landsat 8 image collection for winter (November to January) in the years 2021-2022.
var ndvi_winter = ee.ImageCollection('LANDSAT/LC08/C02/T1_L2')
  .filterBounds(AOI)
  .filter(ee.Filter.calendarRange(11, 1, 'month'))
  .filter(ee.Filter.calendarRange(2021, 2022, 'year'))
  .map(prepSrL8)
  .map(addNDVI)
  .select('SR_NDVI')
  .reduce(ee.Reducer.percentile([90]));

// Visualization parameters for NDVI
var ndviParams = {
  bands: ['SR_NDVI_p90'],
  min: 0,
  max: 1.0
};

// Center the map and add the NDVI layer for visualization.
Map.centerObject(AOI, 9);
Map.addLayer(ndvi_winter.clip(AOI), ndviParams, 'Cloud-free mosaic Winter');

// Export the NDVI image to Google Drive for further analysis.
Export.image.toDrive({
  image: ndvi_winter,
  description: 'ndvi_winter_p90',
  folder: 'RCrafford_MSE_Thesis',
  region: AOI,
  scale: 30,
  crs: 'EPSG:26912',
  maxPixels: 200000000
});
