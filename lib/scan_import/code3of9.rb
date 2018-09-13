class Code3of9
  ENCODE = {
    "!" => "/A",
    "\"" => "/B",
    "#" => "/C",
    "$" => "/D",
    "%" => "/E",
    "&" => "/F",
    "'" => "/G",
    "(" => "/H",
    ")" => "/I",
    "*" => "/J",
    "+" => "/K",
    "," => "/L",
    "/" => "/O",
    ":" => "/Z",
    ";" => "%F",
    "<" => "%G",
    "=" => "%H",
    ">" => "%I",
    "?" => "%J",
    "@" => "%V",
    "[" => "%K",
    "\\" => "%L",
    "]" => "%M",
    "^" => "%N",
    "_" => "%O",
    "`" => "%W",
    "{" => "%P",
    "}" => "%R",
    "|" => "%Q",
    "~" => "%S",
    "a" => "+A",
    "b" => "+B",
    "c" => "+C",
    "d" => "+D",
    "e" => "+E",
    "f" => "+F",
    "g" => "+G",
    "h" => "+H",
    "i" => "+I",
    "j" => "+J",
    "k" => "+K",
    "l" => "+L",
    "m" => "+M",
    "n" => "+N",
    "o" => "+O",
    "p" => "+P",
    "q" => "+Q",
    "r" => "+R",
    "s" => "+S",
    "t" => "+T",
    "u" => "+U",
    "v" => "+V",
    "w" => "+W",
    "x" => "+X",
    "y" => "+Y",
    "z" => "+Z"
  }

  DECODE = ENCODE.inject({}) {|d,e| d[e[1]] = e[0]; d}

  def self.encode(string)
    code = ""

    string.to_s.strip.each_char do |c|
      code << (ENCODE[c] || c)
    end

    return code
  end

  def self.decode(code)
    string = ""

    i = 0
    while i < code.size
      code_part = code[i, 2]
      decoded = DECODE[code_part]

      if !decoded.nil?
        string << decoded
        i += 2
      else
        string << code[i, 1]
        i += 1
      end
    end

    return string
  end
end

