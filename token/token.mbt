///|
/// A token type: a node in the open hierarchy rooted at `token`
/// (`Token.Name.Builtin`, ...). Token types are interned, so equality is
/// identity.
pub struct TokenType {
  priv id : Int
} derive(Eq, Hash, Compare)

///|
pub extend TokenType with Eq::{not_equal, equal}

///|
pub extend TokenType with Hash::{hash, hash_combine}

///|
pub extend TokenType with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend TokenType with Debug::{to_repr}

///|
#deprecated
pub extend TokenType with Show::{output}

///|
priv struct Registry {
  parents : Array[Int]
  names : Array[String]
  children : Array[Map[String, Int]]
  full_names : Array[String]
}

///|
let registry : Registry = {
  parents: [-1],
  names: [""],
  children: [{}],
  full_names: ["Token"],
}

///|
/// The root token type `Token`.
pub let token : TokenType = { id: 0, }

///|
/// The child token type `self.<name>`, created on first use.
///
/// ```mbt check
/// test {
///   let t = @token.name.sub("Builtin").sub("Pseudo")
///   inspect(t, content="Token.Name.Builtin.Pseudo")
///   inspect(t == @token.name_builtin_pseudo, content="true")
/// }
/// ```
pub fn TokenType::sub(self : TokenType, name : String) -> TokenType {
  match registry.children[self.id].get(name) {
    Some(id) => { id, }
    None => {
      let id = registry.parents.length()
      registry.parents.push(self.id)
      registry.names.push(name)
      registry.children.push({})
      registry.full_names.push(registry.full_names[self.id] + "." + name)
      registry.children[self.id][name] = id
      { id, }
    }
  }
}

///|
/// The parent token type, or `None` for the root.
pub fn TokenType::parent(self : TokenType) -> TokenType? {
  let p = registry.parents[self.id]
  if p < 0 {
    None
  } else {
    Some({ id: p, })
  }
}

///|
/// The last path component (`"Builtin"` for `Token.Name.Builtin`); empty for
/// the root.
pub fn TokenType::last(self : TokenType) -> String {
  registry.names[self.id]
}

///|
/// Path components below the root, e.g. `["Name", "Builtin"]`.
pub fn TokenType::path(self : TokenType) -> Array[String] {
  let out = []
  let mut t = self.id
  while t > 0 {
    out.push(registry.names[t])
    t = registry.parents[t]
  }
  out.rev_in_place()
  out
}

///|
/// The ancestors from the root down to `self` (Python's `ttype.split()`).
pub fn TokenType::split(self : TokenType) -> Array[TokenType] {
  let out = []
  let mut t = self.id
  while t >= 0 {
    out.push({ id: t, })
    t = registry.parents[t]
  }
  out.rev_in_place()
  out
}

///|
/// Whether `self` is `other` or one of its descendants (Python's
/// `self in other`).
pub fn TokenType::is_subtype_of(self : TokenType, other : TokenType) -> Bool {
  let mut t = self.id
  while t >= 0 {
    if t == other.id {
      return true
    }
    t = registry.parents[t]
  }
  false
}

///|
/// Direct children created so far.
pub fn TokenType::subtypes(self : TokenType) -> Array[TokenType] {
  registry.children[self.id].values().map(id => TokenType::{ id, }).collect()
}

///|
/// Canonical name, e.g. `Token.Literal.String.Double`.
pub impl Show for TokenType with fn output(self, logger) {
  logger.write_string(registry.full_names[self.id])
}

///|
pub impl Debug for TokenType with fn to_repr(self) {
  @debug.Repr::literal(registry.full_names[self.id])
}

///|
/// Canonical name, e.g. `Token.Literal.String.Double`.
pub fn TokenType::to_string(self : TokenType) -> String {
  registry.full_names[self.id]
}

///|
/// Python's `string_to_tokentype`: `"String.Double"`,
/// `"Token.Literal.String"` and `""` (the root) are accepted.
///
/// ```mbt check
/// test {
///   inspect(
///     @token.from_string("String.Double"),
///     content="Token.Literal.String.Double",
///   )
///   inspect(@token.from_string(""), content="Token")
/// }
/// ```
pub fn from_string(s : StringView) -> TokenType {
  if s.length() == 0 {
    return token
  }
  let mut node = token
  for item in s.split(".") {
    let item = item.to_owned()
    node = if node == token {
      match item {
        "Token" => token
        "String" => string
        "Number" => number
        _ => node.sub(item)
      }
    } else {
      node.sub(item)
    }
  }
  node
}

///|
/// The short CSS class name of a standard token type (`"kc"` for
/// `Keyword.Constant`), if `t` is standard.
pub fn standard_short_name(t : TokenType) -> String? {
  standard_names().get(t)
}

///|
/// Python's `_get_ttype_class`: the standard short name of the nearest
/// standard ancestor followed by the remaining path components.
///
/// ```mbt check
/// test {
///   inspect(@token.css_class(@token.name_builtin.sub("Magic")), content="nbMagic")
/// }
/// ```
pub fn css_class(t : TokenType) -> String {
  let names = standard_names()
  let mut suffix = ""
  let mut cur = t
  while true {
    match names.get(cur) {
      Some(short) => return short + suffix
      None => ()
    }
    suffix = cur.last() + suffix
    match cur.parent() {
      Some(p) => cur = p
      None => return suffix
    }
  }
  suffix
}

///|
/// `Token.Text`
pub let text : TokenType = token.sub("Text")

///|
/// `Token.Text.Whitespace`
pub let text_whitespace : TokenType = text.sub("Whitespace")

///|
/// `Token.Text.Whitespace` (Python's `Whitespace`)
pub let whitespace : TokenType = text_whitespace

///|
/// `Token.Escape`
pub let escape : TokenType = token.sub("Escape")

///|
/// `Token.Error`
pub let error : TokenType = token.sub("Error")

///|
/// `Token.Other`
pub let other : TokenType = token.sub("Other")

///|
/// `Token.Keyword`
pub let keyword : TokenType = token.sub("Keyword")

///|
/// `Token.Keyword.Constant`
pub let keyword_constant : TokenType = keyword.sub("Constant")

///|
/// `Token.Keyword.Declaration`
pub let keyword_declaration : TokenType = keyword.sub("Declaration")

///|
/// `Token.Keyword.Namespace`
pub let keyword_namespace : TokenType = keyword.sub("Namespace")

///|
/// `Token.Keyword.Pseudo`
pub let keyword_pseudo : TokenType = keyword.sub("Pseudo")

///|
/// `Token.Keyword.Reserved`
pub let keyword_reserved : TokenType = keyword.sub("Reserved")

///|
/// `Token.Keyword.Type`
pub let keyword_type : TokenType = keyword.sub("Type")

///|
/// `Token.Name`
pub let name : TokenType = token.sub("Name")

///|
/// `Token.Name.Attribute`
pub let name_attribute : TokenType = name.sub("Attribute")

///|
/// `Token.Name.Builtin`
pub let name_builtin : TokenType = name.sub("Builtin")

///|
/// `Token.Name.Builtin.Pseudo`
pub let name_builtin_pseudo : TokenType = name_builtin.sub("Pseudo")

///|
/// `Token.Name.Class`
pub let name_class : TokenType = name.sub("Class")

///|
/// `Token.Name.Constant`
pub let name_constant : TokenType = name.sub("Constant")

///|
/// `Token.Name.Decorator`
pub let name_decorator : TokenType = name.sub("Decorator")

///|
/// `Token.Name.Entity`
pub let name_entity : TokenType = name.sub("Entity")

///|
/// `Token.Name.Exception`
pub let name_exception : TokenType = name.sub("Exception")

///|
/// `Token.Name.Function`
pub let name_function : TokenType = name.sub("Function")

///|
/// `Token.Name.Function.Magic`
pub let name_function_magic : TokenType = name_function.sub("Magic")

///|
/// `Token.Name.Property`
pub let name_property : TokenType = name.sub("Property")

///|
/// `Token.Name.Label`
pub let name_label : TokenType = name.sub("Label")

///|
/// `Token.Name.Namespace`
pub let name_namespace : TokenType = name.sub("Namespace")

///|
/// `Token.Name.Other`
pub let name_other : TokenType = name.sub("Other")

///|
/// `Token.Name.Tag`
pub let name_tag : TokenType = name.sub("Tag")

///|
/// `Token.Name.Variable`
pub let name_variable : TokenType = name.sub("Variable")

///|
/// `Token.Name.Variable.Class`
pub let name_variable_class : TokenType = name_variable.sub("Class")

///|
/// `Token.Name.Variable.Global`
pub let name_variable_global : TokenType = name_variable.sub("Global")

///|
/// `Token.Name.Variable.Instance`
pub let name_variable_instance : TokenType = name_variable.sub("Instance")

///|
/// `Token.Name.Variable.Magic`
pub let name_variable_magic : TokenType = name_variable.sub("Magic")

///|
/// `Token.Literal`
pub let literal : TokenType = token.sub("Literal")

///|
/// `Token.Literal.Date`
pub let literal_date : TokenType = literal.sub("Date")

///|
/// `Token.Literal.String`
pub let string : TokenType = literal.sub("String")

///|
/// `Token.Literal.String.Affix`
pub let string_affix : TokenType = string.sub("Affix")

///|
/// `Token.Literal.String.Backtick`
pub let string_backtick : TokenType = string.sub("Backtick")

///|
/// `Token.Literal.String.Char`
pub let string_char : TokenType = string.sub("Char")

///|
/// `Token.Literal.String.Delimiter`
pub let string_delimiter : TokenType = string.sub("Delimiter")

///|
/// `Token.Literal.String.Doc`
pub let string_doc : TokenType = string.sub("Doc")

///|
/// `Token.Literal.String.Double`
pub let string_double : TokenType = string.sub("Double")

///|
/// `Token.Literal.String.Escape`
pub let string_escape : TokenType = string.sub("Escape")

///|
/// `Token.Literal.String.Heredoc`
pub let string_heredoc : TokenType = string.sub("Heredoc")

///|
/// `Token.Literal.String.Interpol`
pub let string_interpol : TokenType = string.sub("Interpol")

///|
/// `Token.Literal.String.Other`
pub let string_other : TokenType = string.sub("Other")

///|
/// `Token.Literal.String.Regex`
pub let string_regex : TokenType = string.sub("Regex")

///|
/// `Token.Literal.String.Single`
pub let string_single : TokenType = string.sub("Single")

///|
/// `Token.Literal.String.Symbol`
pub let string_symbol : TokenType = string.sub("Symbol")

///|
/// `Token.Literal.Number`
pub let number : TokenType = literal.sub("Number")

///|
/// `Token.Literal.Number.Bin`
pub let number_bin : TokenType = number.sub("Bin")

///|
/// `Token.Literal.Number.Float`
pub let number_float : TokenType = number.sub("Float")

///|
/// `Token.Literal.Number.Hex`
pub let number_hex : TokenType = number.sub("Hex")

///|
/// `Token.Literal.Number.Integer`
pub let number_integer : TokenType = number.sub("Integer")

///|
/// `Token.Literal.Number.Integer.Long`
pub let number_integer_long : TokenType = number_integer.sub("Long")

///|
/// `Token.Literal.Number.Oct`
pub let number_oct : TokenType = number.sub("Oct")

///|
/// `Token.Operator`
pub let operator : TokenType = token.sub("Operator")

///|
/// `Token.Operator.Word`
pub let operator_word : TokenType = operator.sub("Word")

///|
/// `Token.Punctuation`
pub let punctuation : TokenType = token.sub("Punctuation")

///|
/// `Token.Punctuation.Marker`
pub let punctuation_marker : TokenType = punctuation.sub("Marker")

///|
/// `Token.Comment`
pub let comment : TokenType = token.sub("Comment")

///|
/// `Token.Comment.Hashbang`
pub let comment_hashbang : TokenType = comment.sub("Hashbang")

///|
/// `Token.Comment.Multiline`
pub let comment_multiline : TokenType = comment.sub("Multiline")

///|
/// `Token.Comment.Preproc`
pub let comment_preproc : TokenType = comment.sub("Preproc")

///|
/// `Token.Comment.PreprocFile`
pub let comment_preprocfile : TokenType = comment.sub("PreprocFile")

///|
/// `Token.Comment.Single`
pub let comment_single : TokenType = comment.sub("Single")

///|
/// `Token.Comment.Special`
pub let comment_special : TokenType = comment.sub("Special")

///|
/// `Token.Generic`
pub let generic : TokenType = token.sub("Generic")

///|
/// `Token.Generic.Deleted`
pub let generic_deleted : TokenType = generic.sub("Deleted")

///|
/// `Token.Generic.Emph`
pub let generic_emph : TokenType = generic.sub("Emph")

///|
/// `Token.Generic.Error`
pub let generic_error : TokenType = generic.sub("Error")

///|
/// `Token.Generic.Heading`
pub let generic_heading : TokenType = generic.sub("Heading")

///|
/// `Token.Generic.Inserted`
pub let generic_inserted : TokenType = generic.sub("Inserted")

///|
/// `Token.Generic.Output`
pub let generic_output : TokenType = generic.sub("Output")

///|
/// `Token.Generic.Prompt`
pub let generic_prompt : TokenType = generic.sub("Prompt")

///|
/// `Token.Generic.Strong`
pub let generic_strong : TokenType = generic.sub("Strong")

///|
/// `Token.Generic.Subheading`
pub let generic_subheading : TokenType = generic.sub("Subheading")

///|
/// `Token.Generic.EmphStrong`
pub let generic_emphstrong : TokenType = generic.sub("EmphStrong")

///|
/// `Token.Generic.Traceback`
pub let generic_traceback : TokenType = generic.sub("Traceback")

///|
let standard_table : Ref[Map[TokenType, String]?] = Ref(None)

///|
/// Standard token types and their short CSS names (Python's
/// `STANDARD_TYPES`).
pub fn standard_names() -> Map[TokenType, String] {
  match standard_table.val {
    Some(m) => m
    None => {
      let m : Map[TokenType, String] = Map::from_array([
        (token, ""),
        (text, ""),
        (text_whitespace, "w"),
        (escape, "esc"),
        (error, "err"),
        (other, "x"),
        (keyword, "k"),
        (keyword_constant, "kc"),
        (keyword_declaration, "kd"),
        (keyword_namespace, "kn"),
        (keyword_pseudo, "kp"),
        (keyword_reserved, "kr"),
        (keyword_type, "kt"),
        (name, "n"),
        (name_attribute, "na"),
        (name_builtin, "nb"),
        (name_builtin_pseudo, "bp"),
        (name_class, "nc"),
        (name_constant, "no"),
        (name_decorator, "nd"),
        (name_entity, "ni"),
        (name_exception, "ne"),
        (name_function, "nf"),
        (name_function_magic, "fm"),
        (name_property, "py"),
        (name_label, "nl"),
        (name_namespace, "nn"),
        (name_other, "nx"),
        (name_tag, "nt"),
        (name_variable, "nv"),
        (name_variable_class, "vc"),
        (name_variable_global, "vg"),
        (name_variable_instance, "vi"),
        (name_variable_magic, "vm"),
        (literal, "l"),
        (literal_date, "ld"),
        (string, "s"),
        (string_affix, "sa"),
        (string_backtick, "sb"),
        (string_char, "sc"),
        (string_delimiter, "dl"),
        (string_doc, "sd"),
        (string_double, "s2"),
        (string_escape, "se"),
        (string_heredoc, "sh"),
        (string_interpol, "si"),
        (string_other, "sx"),
        (string_regex, "sr"),
        (string_single, "s1"),
        (string_symbol, "ss"),
        (number, "m"),
        (number_bin, "mb"),
        (number_float, "mf"),
        (number_hex, "mh"),
        (number_integer, "mi"),
        (number_integer_long, "il"),
        (number_oct, "mo"),
        (operator, "o"),
        (operator_word, "ow"),
        (punctuation, "p"),
        (punctuation_marker, "pm"),
        (comment, "c"),
        (comment_hashbang, "ch"),
        (comment_multiline, "cm"),
        (comment_preproc, "cp"),
        (comment_preprocfile, "cpf"),
        (comment_single, "c1"),
        (comment_special, "cs"),
        (generic, "g"),
        (generic_deleted, "gd"),
        (generic_emph, "ge"),
        (generic_error, "gr"),
        (generic_heading, "gh"),
        (generic_inserted, "gi"),
        (generic_output, "go"),
        (generic_prompt, "gp"),
        (generic_strong, "gs"),
        (generic_subheading, "gu"),
        (generic_emphstrong, "ges"),
        (generic_traceback, "gt"),
      ])
      standard_table.val = Some(m)
      m
    }
  }
}
