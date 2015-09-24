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


  createTodosChannel: (todos, activeFilter) ->
    new FooterViewChannel(
      todos.todoList, todos.withComplete, this, activeFilter)



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
      .withTransform (todoListWithCompletePayload) ->
        todoListWithCompletePayload
          .filter(([todo, isCompleted]) -> !isCompleted)
          .toSetVariable()
          .map ({length}) ->
            [length, if length is 1 then 'item' else 'items'].join(' ')


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @todoListWithComplete
      .toTarget @todoListFooterView.clearCompletedIsVisibleVar
      .withTransform (todoListWithCompletePayload) ->
        todoListWithCompletePayload
          .filter(([todo, isCompleted]) -> isCompleted)
          .toSetVariable()
          .map ({length}) -> length > 0


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSources(
        @todoListFooterView.clearCompletedClickEvt, @todoListWithComplete)
      .toTarget @todoList
      .withTransform ([clearCompletedPayload, todoListWithCompletePayload]) =>
        todoListWithCompletePayload
          .replaceByNoop(clearCompletedPayload)
          .filter ([todo, isCompleted]) -> !isCompleted
          .map ([todo]) -> todo


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @todoList
      .toTarget @todoListFooterView.isVisibleVar
      .withTransform (todoListPayload) ->
        todoListPayload.toSetVariable().map ({length}) -> length > 0
