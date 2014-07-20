
module.exports = (Handlebars) ->
  Handlebars.registerHelper 'compare', (lvalue, rvalue, options) ->

    throw new Error("Handlerbars Helper 'compare' needs 2 parameters") if (arguments.length < 3)

    operator = options.hash.operator or "=="

    operators =
      '=='     : (l,r) -> return l == r
      '!='     : (l,r) -> return l != r
      '<'      : (l,r) -> return l < r
      '>'      : (l,r) -> return l > r
      '<='     : (l,r) -> return l <= r
      '>='     : (l,r) -> return l >= r
      'typeof' : (l,r) -> return typeof l == r

    throw new Error("Handlerbars Helper 'compare' doesn't know the operator " + operator) if (!operators[operator])

    result = operators[operator](lvalue, rvalue)

    if result
      return options.fn(this)
    else
      return options.inverse(this)
