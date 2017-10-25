
proxyquire = require('proxyquire').noPreserveCache()
sinon = require('sinon')

fixtures = require('../fixtures')
createCompilationResultSchema = require('../schemas/compilation-result')
{assert, compileFixture} = require('../utils')


describe('compile() · API Blueprint', ->
  describe('causing a \'missing title\' warning', ->
    compilationResult = undefined

    beforeEach((done) ->
      compileFixture(fixtures.missingTitleAnnotation.apiBlueprint, (args...) ->
        [err, compilationResult] = args
        done(err)
      )
    )

    it('produces one annotation and no transaction', ->
      assert.jsonSchema(compilationResult, createCompilationResultSchema(
        annotations: 1
        transactions: 0
      ))
    )
    context('the annotation', ->
      it('is warning', ->
        assert.equal(compilationResult.annotations[0].type, 'warning')
      )
      it('comes from the parser', ->
        assert.equal(compilationResult.annotations[0].component, 'apiDescriptionParser')
      )
      it('has message', ->
        assert.include(compilationResult.annotations[0].message.toLowerCase(), 'expected api name')
      )
    )
  )

  describe('causing a \'not found within URI Template\' warning', ->
    # The warning was previously handled by compiler, but now parser should
    # already provide the same kind of warning.

    compilationResult = undefined

    beforeEach((done) ->
      compileFixture(fixtures.notSpecifiedInUriTemplateAnnotation.apiBlueprint, (args...) ->
        [err, compilationResult] = args
        done(err)
      )
    )

    it('produces one annotation and one transaction', ->
      assert.jsonSchema(compilationResult, createCompilationResultSchema(
        annotations: 1
        transactions: 1
      ))
    )
    context('the annotation', ->
      it('is warning', ->
        assert.equal(compilationResult.annotations[0].type, 'warning')
      )
      it('comes from the parser', ->
        assert.equal(compilationResult.annotations[0].component, 'apiDescriptionParser')
      )
      it('has message', ->
        assert.include(compilationResult.annotations[0].message.toLowerCase(), 'not found within')
        assert.include(compilationResult.annotations[0].message.toLowerCase(), 'uri template')
      )
    )
  )

  describe('with multiple transaction examples', ->
    detectTransactionExampleNumbers = sinon.spy(require('../../src/detect-transaction-example-numbers'))
    compilationResult = undefined
    expected = [
      {exampleName: '', requestContentType: 'application/json', responseStatusCode: 200}
      {exampleName: 'Example 1', requestContentType: 'application/json', responseStatusCode: 200}
      {exampleName: 'Example 2', requestContentType: 'text/plain', responseStatusCode: 415}
    ]

    beforeEach((done) ->
      stubs = {'./detect-transaction-example-numbers': detectTransactionExampleNumbers}
      compileFixture(fixtures.multipleTransactionExamples.apiBlueprint, {stubs}, (args...) ->
        [err, compilationResult] = args
        done(err)
      )
    )

    it('calls the detection of transaction examples', ->
      assert.isTrue(detectTransactionExampleNumbers.called)
    )
    it("produces no annotations and #{expected.length} transactions", ->
      assert.jsonSchema(compilationResult, createCompilationResultSchema(
        annotations: 0
        transactions: expected.length
      ))
    )
    for expectations, i in expected
      do (expectations, i) ->
        context("transaction ##{i + 1}", ->
          {exampleName, requestContentType, responseStatusCode} = expectations

          it("is identified as part of #{JSON.stringify(exampleName)}", ->
            assert.equal(
              compilationResult.transactions[i].origin.exampleName,
              exampleName
            )
          )
          it("has request with Content-Type: #{requestContentType}", ->
            assert.equal(
              compilationResult.transactions[i].request.headers['Content-Type'].value,
              requestContentType
            )
          )
          it("has response with status code #{responseStatusCode}", ->
            assert.equal(
              compilationResult.transactions[i].response.status,
              responseStatusCode
            )
          )
        )
  )

  describe('without multiple transaction examples', ->
    detectTransactionExampleNumbers = sinon.spy(require('../../src/detect-transaction-example-numbers'))
    compilationResult = undefined

    beforeEach((done) ->
      stubs = {'./detect-transaction-example-numbers': detectTransactionExampleNumbers}
      compileFixture(fixtures.oneTransactionExample.apiBlueprint, {stubs}, (args...) ->
        [err, compilationResult] = args
        done(err)
      )
    )

    it('calls the detection of transaction examples', ->
      assert.isTrue(detectTransactionExampleNumbers.called)
    )
    it('produces no annotations and one transaction', ->
      assert.jsonSchema(compilationResult, createCompilationResultSchema(
        annotations: 0
        transactions: 1
      ))
    )
    context('the transaction', ->
      it("is identified as part of no example in \'origin\'", ->
        assert.equal(compilationResult.transactions[0].origin.exampleName, '')
      )
      it("is identified as part of Example 1 in \'pathOrigin\'", ->
        assert.equal(compilationResult.transactions[0].pathOrigin.exampleName, 'Example 1')
      )
    )
  )

  describe('with arbitrary action', ->
    compilationResult = undefined
    filename = 'apiDescription.apib'

    beforeEach((done) ->
      compileFixture(fixtures.arbitraryAction.apiBlueprint, {filename}, (args...) ->
        [err, compilationResult] = args
        done(err)
      )
    )

    it('produces no annotations and two transactions', ->
      assert.jsonSchema(compilationResult, createCompilationResultSchema(
        annotations: 0
        transactions: 2
      ))
    )
    context('action within a resource', ->
      it('has URI inherited from the resource', ->
        assert.equal(compilationResult.transactions[0].request.uri, '/resource/1')
      )
      it('has its method', ->
        assert.equal(compilationResult.transactions[0].request.method, 'GET')
      )
    )
    context('arbitrary action', ->
      it('has its own URI', ->
        assert.equal(compilationResult.transactions[1].request.uri, '/arbitrary/sample')
      )
      it('has its method', ->
        assert.equal(compilationResult.transactions[1].request.method, 'POST')
      )
    )
  )

  describe('without sections', ->
    compilationResult = undefined
    filename = 'apiDescription.apib'

    beforeEach((done) ->
      compileFixture(fixtures.withoutSections.apiBlueprint, {filename}, (args...) ->
        [err, compilationResult] = args
        done(err)
      )
    )

    it('produces no annotations and one transaction', ->
      assert.jsonSchema(compilationResult, createCompilationResultSchema(
        annotations: 0
        transactions: 1
      ))
    )
    context('\'origin\'', ->
      it('uses filename as API name', ->
        assert.equal(compilationResult.transactions[0].origin.apiName, filename)
      )
      it('uses empty string as resource group name', ->
        assert.equal(compilationResult.transactions[0].origin.resourceGroupName, '')
      )
      it('uses URI as resource name', ->
        assert.equal(compilationResult.transactions[0].origin.resourceName, '/message')
      )
      it('uses method as action name', ->
        assert.equal(compilationResult.transactions[0].origin.actionName, 'GET')
      )
    )
    context('\'pathOrigin\'', ->
      it('uses empty string as API name', ->
        assert.equal(compilationResult.transactions[0].pathOrigin.apiName, '')
      )
      it('uses empty string as resource group name', ->
        assert.equal(compilationResult.transactions[0].pathOrigin.resourceGroupName, '')
      )
      it('uses URI as resource name', ->
        assert.equal(compilationResult.transactions[0].pathOrigin.resourceName, '/message')
      )
      it('uses method as action name', ->
        assert.equal(compilationResult.transactions[0].pathOrigin.actionName, 'GET')
      )
    )
  )

  describe('with different sample and default value of URI parameter', ->
    compilationResult = undefined

    beforeEach((done) ->
      compileFixture(fixtures.preferSample.apiBlueprint, (args...) ->
        [err, compilationResult] = args
        done(err)
      )
    )

    it('produces no annotations and one transaction', ->
      assert.jsonSchema(compilationResult, createCompilationResultSchema(
        annotations: 0
        transactions: 1
      ))
    )
    it('expands the request URI using the sample value', ->
      assert.equal(compilationResult.transactions[0].request.uri, '/honey?beekeeper=Pavan')
    )
  )
)
