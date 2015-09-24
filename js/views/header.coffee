'use strict'


Transmitter = require 'transmitter'

{getKeycodeMatcher} = require '../helpers'


module.exports = class HeaderView extends Transmitter.Nodes.Record

  constructor: (@$element) ->
    @newTodoInputEl = @$element.find('.new-todo')[0]


  init: (tr) ->
    @clearNewTodoLabelInputChannel.init(tr)
    return this


  @defineLazy 'newTodoLabelInputVar', ->
    new Transmitter.DOMElement.InputValueVar(@newTodoInputEl)


  @defineLazy 'newTodoKeypressEvt', ->
    new Transmitter.DOMElement.DOMEvent(@newTodoInputEl, 'keyup')

  matchEnter = getKeycodeMatcher 'enter'
  matchEscEnter = getKeycodeMatcher 'enter', 'esc'

  createTodosChannel: (todos) ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSources @newTodoLabelInputVar, @newTodoKeypressEvt
      .toTarget todos.todoList
      .withTransform ([labelPayload, keypressPayload], tr) =>
        labelPayload
          .replaceByNoop(matchEnter(keypressPayload))
          .map (label) -> todos.create().init(tr, {label})
          .toAppendListElement()


  @defineLazy 'clearNewTodoLabelInputChannel', ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @newTodoKeypressEvt
      .toTarget @newTodoLabelInputVar
      .withTransform (keypressPayload) ->
        matchEscEnter(keypressPayload).map -> ''
