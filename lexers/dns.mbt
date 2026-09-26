// Hand-written parts of pygments/lexers/dns.py.

///|
fn dns_zone_lexer_analyse(text : String) -> Double {
  if text.has_prefix("$ORIGIN") {
    1.0
  } else {
    0.0
  }
}
