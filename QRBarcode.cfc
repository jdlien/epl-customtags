component {
  property name="loaderZX" hint="JavaLoader object for ZXing classes";
  property name="fmtCodaBar" hint="Reference to CodaBar barcode format";
  property name="fmtQRCode" hint="Reference to QR Code barcode format";
  property name="codaBarWriter" hint="Java object for generating CODABAR barcodes";
  property name="qrCodeWriter" hint="Java object for generating QR codes";
  property name="qrHintMaps" hint="Hashtable instances for QR Code error correction";

  public function init() {
    loadZxing()
    return this
  }

  private void function loadZxing() {
    // TODO: Make this path configurable in the .appsenv file
    variables.loaderZX = new JavaLoader([
      'D:\inetpub\lib\zxing\core-3.5.2.jar',
      'D:\inetpub\lib\zxing\javase-3.5.2.jar'
    ])

    var barcodeFormat = variables.loaderZX.create('com.google.zxing.BarcodeFormat')

    variables.fmtCodaBar = barcodeFormat.CODABAR
    variables.fmtQRCode = barcodeFormat.QR_CODE
    variables.qrCodeWriter = variables.loaderZX.create('com.google.zxing.qrcode.QRCodeWriter')
    variables.codaBarWriter = variables.loaderZX.create('com.google.zxing.oned.CodaBarWriter')

    // Create hints maps for each mode of QR Code error correction
    variables.qrHintMaps = {}
    var errorLevels = ['L', 'M', 'Q', 'H']

    for (var level in errorLevels) {
      var hintsMap = variables.loaderZX.create('java.util.Hashtable')
      hintsMap.put(
        variables.loaderZX.create('com.google.zxing.EncodeHintType').ERROR_CORRECTION,
        variables.loaderZX.create('com.google.zxing.qrcode.decoder.ErrorCorrectionLevel')[level]
      )
      variables.qrHintMaps[level] = hintsMap
    }
  }

  /** Generates a barcode image from the given data.
   * @param data The data to be encoded
   * @param width The width of the image
   * @param height The height of the image
   * @param type The type of barcode to generate (QR or CODABAR)
   * @param errorCorrection The error correction level for QR codes: L 7%, M 15%, Q 25%, H 30%
   * @return The generated image as a byte array
   */
  private any function getCode(
    required string data,
    numeric width=150,
    numeric height=150,
    string type='QR',
    string errorCorrection='L'
  ) {
    errorCorrection = uCase(errorCorrection)
    if (!listFind('L,M,Q,H', errorCorrection)) errorCorrection = 'L'

    var code = (type == 'CODABAR')
      ? variables.codaBarWriter.encode('A#data#A', variables.fmtCodaBar, width, height)
      : variables.qrCodeWriter.encode(data, variables.fmtQRCode, width, height, variables.qrHintMaps[errorCorrection])

    var bufferedImage = variables.loaderZX.create('com.google.zxing.client.j2se.MatrixToImageWriter').toBufferedImage(code)
    var imageStream = createObject('java', 'java.io.ByteArrayOutputStream').init()
    createObject('java', 'javax.imageio.ImageIO').write(bufferedImage, 'png', imageStream)
    return imageStream.toByteArray()
  }

  public any function getQRCode(required string data, numeric width=150, numeric height=150, string errorCorrection='L') {
    return variables.getCode(data, width, height, 'QR', errorCorrection)
  }

  public any function getBarcode(required string data, numeric width=350, numeric height=52) {
    return variables.getCode(data, width, height, 'CODABAR')
  }

  public string function getQRCodeBase64(required string data, numeric width=150, numeric height=150, string errorCorrection='L') {
    return toBase64(this.getQRCode(data, width, height, errorCorrection))
  }

  public string function getBarcodeBase64(required string data, numeric width=350, numeric height=52) {
    return toBase64(this.getBarcode(data, width, height))
  }
}
