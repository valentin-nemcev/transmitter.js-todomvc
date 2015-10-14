'use strict'


Transmitter = require 'transmitter'

{VisibilityToggleVar} = require '../helpers'


module.exports = class FooterView

  constructor: (@$element) ->

    @$clearCompleted = @$element.find('.clear-completed')
    @completeCountVar =
      new Transmitter.DOMElement.TextVar(@$element.find('.todo-count')[0])

    @clearCompletedIsVisibleVar =
      new VisibilityToggleVar(@$clearCompleted)

    @clearCompletedClickEvt =
      new Transmitter.DOMElement.DOMEvent(@$clearCompleted[0], 'click')

    @isVisibleVar = new VisibilityToggleVar(@$element)

    $filters = @$element.find('.filters')
    @activeFilter =
      new class ActiveFilterSelector extends Transmitter.Nodes.Variable
        get: ->
          ($filters.find('a.selected').attr('href') ? '')
            .match(/\w*$/)[0] || 'all'
        set: (filter) ->
          filter = '' if filter is 'all'
          $filters.find('a').removeClass('selected')
            .filter("[href='#/#{filter}']").addClass('selected')


  init: (tr) ->


  createTodosChannel: (todos, activeFilter) ->
    new FooterViewChannel(
      todos.todoList, todos.withComplete, this, activeFilter)



class FooterViewChannel extends Transmitter.Channels.CompositeChannel

  constructor: (@todoList, @todoListWithComplete, @todoListFooterView, @activeFilter) ->

    @defineSimpleChannel()
      .inForwardDirection()
      .fromSource @activeFilter
      .toTarget @todoListFooterView.activeFilter

    @defineSimpleChannel()
      .inForwardDirection()
      .fromSource @todoListWithComplete
      .toTarget @todoListFooterView.completeCountVar
      .withTransform (todoListWithCompletePayload) ->
        todoListWithCompletePayload
          .filter(([todo, isCompleted]) -> !isCompleted)
          .toSetVariable()
          .map ({length}) ->
            [length, if length is 1 then 'item' else 'items'].join(' ')

    @defineSimpleChannel()
      .inForwardDirection()
      .fromSource @todoListWithComplete
      .toTarget @todoListFooterView.clearCompletedIsVisibleVar
      .withTransform (todoListWithCompletePayload) ->
        todoListWithCompletePayload
          .filter(([todo, isCompleted]) -> isCompleted)
          .toSetVariable()
          .map ({length}) -> length > 0

    @defineSimpleChannel()
      .inBackwardDirection()
      .fromSources(
        @todoListFooterView.clearCompletedClickEvt, @todoListWithComplete)
      .toTarget @todoList
      .withTransform ([clearCompletedPayload, todoListWithCompletePayload]) =>
        todoListWithCompletePayload
          .replaceByNoop(clearCompletedPayload)
          .filter ([todo, isCompleted]) -> !isCompleted
          .map ([todo]) -> todo

    @defineSimpleChannel()
      .inForwardDirection()
      .fromSource @todoList
      .toTarget @todoListFooterView.isVisibleVar
      .withTransform (todoListPayload) ->
        todoListPayload.toSetVariable().map ({length}) -> length > 0
