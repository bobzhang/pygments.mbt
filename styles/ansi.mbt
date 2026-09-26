///|
/// Python's `pygments.style._ansimap`: the default RGB value of every ANSI
/// color name.
pub let ansimap : Map[String, String] = {
  "ansiblack": "000000",
  "ansired": "7f0000",
  "ansigreen": "007f00",
  "ansiyellow": "7f7fe0",
  "ansiblue": "00007f",
  "ansimagenta": "7f007f",
  "ansicyan": "007f7f",
  "ansigray": "e5e5e5",
  "ansibrightblack": "555555",
  "ansibrightred": "ff0000",
  "ansibrightgreen": "00ff00",
  "ansibrightyellow": "ffff00",
  "ansibrightblue": "0000ff",
  "ansibrightmagenta": "ff00ff",
  "ansibrightcyan": "00ffff",
  "ansiwhite": "ffffff",
}

///|
/// Python's `pygments.style._deprecated_ansicolors`: the pre-2.4 `#ansixxx`
/// names and their replacements.
pub let deprecated_ansicolors : Map[String, String] = {
  "#ansiblack": "ansiblack",
  "#ansidarkred": "ansired",
  "#ansidarkgreen": "ansigreen",
  "#ansibrown": "ansiyellow",
  "#ansidarkblue": "ansiblue",
  "#ansipurple": "ansimagenta",
  "#ansiteal": "ansicyan",
  "#ansilightgray": "ansigray",
  "#ansidarkgray": "ansibrightblack",
  "#ansired": "ansibrightred",
  "#ansigreen": "ansibrightgreen",
  "#ansiyellow": "ansibrightyellow",
  "#ansiblue": "ansibrightblue",
  "#ansifuchsia": "ansibrightmagenta",
  "#ansiturquoise": "ansibrightcyan",
  "#ansiwhite": "ansiwhite",
}

///|
/// Python's `pygments.style.ansicolors`: whether `name` is an ANSI color name.
pub fn is_ansicolor(name : String) -> Bool {
  ansimap.contains(name)
}
