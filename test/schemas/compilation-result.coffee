
createLocationSchema = require('./location')
createOriginSchema = require('./origin')
createPathOriginSchema = require('./path-origin')


addMinMax = (schema, n) ->
  if n is true
    schema.minItems = 1
  else
    schema.minItems = n
    schema.maxItems = n
  schema


module.exports = (options = {}) ->
  # Either filename string or undefined (= doesn't matter)
  filename = options.filename

  # Either exact number or true (= more than one)
  annotations = options.annotations or 0
  transactions = options.transactions or 0

  annotationSchema =
    type: 'object'
    properties:
      type:
        type: 'string'
        enum: ['error', 'warning']
      component:
        type: 'string'
        enum: [
          'apiDescriptionParser'
          'parametersValidation'
          'uriTemplateExpansion'
        ]
      message: {type: 'string'}
      location: createLocationSchema()
      origin: createOriginSchema({filename})
    required: ['type', 'component', 'message', 'location']
    dependencies:
      origin:
        properties:
          component:
            enum: ['parametersValidation', 'uriTemplateExpansion']
    additionalProperties: false

  requestSchema =
    type: 'object'
    properties:
      uri: {type: 'string', pattern: '^/'}
      method: {type: 'string'}
      headers:
        type: 'object'
        patternProperties:
          '': # property of any name
            type: 'object'
            properties:
              value: {type: 'string'}
      body: {type: 'string'}
    required: ['uri', 'method', 'headers']
    additionalProperties: false

  responseSchema =
    type: 'object'
    properties:
      status: {type: 'string'}
      headers:
        type: 'object'
        patternProperties:
          '': # property of any name
            type: 'object'
            properties:
              value: {type: 'string'}
      body: {type: 'string'}
      schema: {type: 'string'}
    required: ['status', 'headers', 'body', 'schema']
    additionalProperties: false

  transactionSchema =
    type: 'object'
    properties:
      request: requestSchema
      response: responseSchema
      origin: createOriginSchema({filename})
      name: {type: 'string'}
      pathOrigin: createPathOriginSchema()
      path: {type: 'string'}
    required: ['request', 'response', 'origin', 'name', 'pathOrigin', 'path']
    additionalProperties: false

  transactionsSchema = addMinMax(
    type: 'array'
    items: transactionSchema
  , transactions)

  annotationsSchema = addMinMax(
    type: 'array'
    items: annotationSchema
  , annotations)

  {
    type: 'object'
    properties:
      mediaType: {anyOf: [{type: 'string'}, {type: 'null'}]}
      transactions: transactionsSchema
      annotations: annotationsSchema
    required: ['mediaType', 'transactions', 'annotations']
    additionalProperties: false
  }
