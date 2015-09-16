'use strict'


Transmitter = require 'transmitter'

{VisibilityToggleVar} = require '../helpers'


module.exports = class FooterView extends Transmitter.Nodes.Record

  constructor: (@$element) ->

  init: (tr) ->


  @defineLazy 'completeCountVar', ->
    new Transmitter.DOMElement.TextVar(@$element.find('.todo-count')[0])


  @defineLazy 'clearCompletedIsVisibleVar', ->
    new VisibilityToggleVar(@$element.find('.clear-completed'))


  @defineLazy 'clearCompletedClickEvt', ->
    new Transmitter.DOMElement
      .DOMEvent(@$element.find('.clear-completed')[0], 'click')


  @defineLazy 'isVisibleVar', ->
    new VisibilityToggleVar(@$element)

  @defineLazy 'activeFilter', ->
    $filters = @$element.find('.filters')
    new class ActiveFilterSelector extends Transmitter.Nodes.Variable
      get: ->
        ($filters.find('a.selected').attr('href') ? '')
          .match(/\w*$/)[0] || 'all'
      set: (filter) ->
        filter = '' if filter is 'all'
        $filters.find('a').removeClass('selected')
          .filter("[href='#/#{filter}']").addClass('selected')


  createTodoListChannel: (todoList, todoListWithComplete, activeFilter) ->
    new FooterViewChannel(
      todoList, todoListWithComplete, this, activeFilter)



class FooterViewChannel extends Transmitter.Channels.CompositeChannel

  constructor:
    (@todoList, @todoListWithComplete, @todoListFooterView, @activeFilter) ->


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @activeFilter
      .toTarget @todoListFooterView.activeFilter


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @todoListWithComplete
      .toTarget @todoListFooterView.completeCountVar
      .withTransform (todoListWithComplete) ->
        Transmitter.Payloads.Variable.setLazy(->
          count = todoListWithComplete.get()
            .filter(([todo, isCompleted]) -> !isCompleted)
            .length
          items = if count is 1 then 'item' else 'items'
          "#{count} #{items} left"
        )


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @todoListWithComplete
      .toTarget @todoListFooterView.clearCompletedIsVisibleVar
      .withTransform (todoListWithComplete) ->
        Transmitter.Payloads.Variable.setLazy(->
          count = todoListWithComplete.get()
            .filter(([todo, isCompleted]) -> isCompleted)
            .length
          count > 0
        )


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @todoListFooterView.clearCompletedClickEvt
      .fromSource @todoListWithComplete
      .toTarget @todoList
      .withTransform (payloads) =>
        clearCompleted = payloads.get(@todoListFooterView.clearCompletedClickEvt)
        todoListWithComplete = payloads.get(@todoListWithComplete)
        if clearCompleted.get?
          todoListWithComplete
            .filter ([todo, isCompleted]) -> !isCompleted
            .map ([todo]) -> todo
        else
          clearCompleted


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @todoList
      .toTarget @todoListFooterView.isVisibleVar
      .withTransform (payload) ->
        Transmitter.Payloads.Variable.setLazy ->
          payload.get().length > 0
