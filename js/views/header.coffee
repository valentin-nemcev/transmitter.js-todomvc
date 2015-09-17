'use strict'


keycode = require 'keycode'

Transmitter = require 'transmitter'


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


  createTodosChannel: (todos) ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @newTodoLabelInputVar
      .fromSource @newTodoKeypressEvt
      .toTarget todos.list
      .withTransform (payloads, tr) =>
        label    = payloads.get(@newTodoLabelInputVar)
        keypress = payloads.get(@newTodoKeypressEvt)

        key = keycode(keypress.get?())
        if key is 'enter'
          todo = todos.create().init(tr, label: label.get())
          Transmitter.Payloads.List.appendConst(todo)
        else
          Transmitter.Payloads.noop()


  @defineLazy 'clearNewTodoLabelInputChannel', ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @newTodoKeypressEvt
      .toTarget @newTodoLabelInputVar
      .withTransform (keypress) ->
        key = keycode(keypress.get?())
        if key in ['esc', 'enter']
          Transmitter.Payloads.Variable.setConst('')
        else
          Transmitter.Payloads.noop()