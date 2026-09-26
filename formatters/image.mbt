///|
/// Metadata of the PIL-based image formatters. They are listed like in
/// Python, but constructing one raises the error Python raises when the
/// Python Imaging Library is not installed.
let image_formatter_infos : Array[FormatterInfo] = [
  image_info(
    "BmpImageFormatter",
    "img_bmp",
    ["bmp", "bitmap"],
    ["*.bmp"],
    "a bitmap",
  ),
  image_info("GifImageFormatter", "img_gif", ["gif"], ["*.gif"], "a GIF"),
  image_info("ImageFormatter", "img", ["img", "IMG", "png"], ["*.png"], "a PNG"),
  image_info(
    "JpgImageFormatter",
    "img_jpg",
    ["jpg", "jpeg"],
    ["*.jpg"],
    "a JPEG",
  ),
]

///|
fn image_info(
  class_name : String,
  name : String,
  aliases : Array[String],
  filenames : Array[String],
  what : String,
) -> FormatterInfo {
  {
    class_name,
    name,
    aliases,
    filenames,
    description: "Create \{what} image from source code. This uses the Python Imaging Library to generate a pixmap from the source code.",
  }
}

///|
/// Constructor of the image formatters: always fails (no PIL).
fn image_formatter(
  _options : @lexer.Options,
  _style : @styles.Style?,
) -> Formatter raise {
  raise FormatterError("Python Imaging Library is required for this formatter")
}
