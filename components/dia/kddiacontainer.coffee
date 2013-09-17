class KDDiaContainer extends JView

  constructor:(options = {}, data)->
    options.cssClass = KD.utils.curry 'kddia-container', options.cssClass

    if options.draggable
      options.draggable = {}  unless 'object' is typeof options.draggable

    options.itemClass ?= KDDiaObject
    super options, data
    @dias = {}

  mouseDown:->
    super
    @emit "HighlightLines", (dia for key, dia of @dias)

  addDia:(diaObj, pos = {})->
    @addSubView diaObj
    diaObj.on "DiaObjectClicked", => @emit "HighlightLines", diaObj
    @dias[diaObj.getId()] = diaObj
    @emit "NewDiaObjectAdded", this, diaObj

    diaObj.setX pos.x  if pos.x?
    diaObj.setY pos.y  if pos.y?

    return diaObj

  addItem:(data, options={})->
    itemClass = @getOption 'itemClass'
    @addDia new itemClass options, data