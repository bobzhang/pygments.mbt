///|
/// Shorthand used by the generated tables: a rule from the pattern pool.
fn r(
  pattern : Int,
  flags : Int,
  action : @lexer.Action,
  transition : Array[@lexer.StateOp]?,
) -> @lexer.Rule {
  @lexer.Rule::new(pattern_pool[pattern], flags, action, transition)
}
