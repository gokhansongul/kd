KDObject = require './../../core/object.coffee'

module.exports = class KDModalViewStack extends KDObject

  constructor: (options={}, data)->
    options.lastToFirst ?= no
    super options, data

    @modals = []

  addModal: (modal)->

    modal.on "KDObjectWillBeDestroyed", => @next()

    {lastToFirst} = @getOptions()

    @modals.push modal

    KD.utils.defer => # deferring to help reposition on hiding
      modal.hide()
      if lastToFirst
        @modals.forEach (modal)-> modal.hide()
        @modals.last.show()
      else
        @modals.first.show()

    return modal

  next: ->
    {lastToFirst} = @getOptions()

    if lastToFirst
      @modals.pop()
      @modals.last?.show()
    else
      @modals.shift()
      @modals.first?.show()

  destroy: ->
    @modals.forEach (modal)-> KD.utils.defer -> modal.destroy()
    @modals = []
    super