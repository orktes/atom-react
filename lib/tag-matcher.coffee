class TagMacher
  startRegex: /\S/
  endRegex: /\S(\s+)?$/

  constructor: (editor) ->
    @editor = editor

  lineStartsWithOpeningTag: (bufferLine) ->
    if match = bufferLine.match(/\S/)
      scopeDescriptor = @editor.tokenForBufferPosition([bufferRow, match.index])
      return scopeDescriptor.scopes.indexOf('tag.open.js') > -1 and
             scopeDescriptor.scopes.indexOf('meta.tag.attribute-name.js') == -1

    return false

  lineStartWithAttribute: (bufferLine) ->
    if match = bufferLine.match(/\S/)
      scopeDescriptor = @editor.tokenForBufferPosition([bufferRow, match.index])
      return scopeDescriptor.scopes.indexOf('meta.tag.attribute-name.js') > -1

    return false

  lineStartsWithClosingTag: (bufferRow) ->
    if match = bufferLine.match(/\S/)
      scopeDescriptor = @editor.tokenForBufferPosition([bufferRow, match.index])
      return scopeDescriptor.scopes.indexOf('tag.closed.js') > -1

    return false

module.exports = TagMacher;
