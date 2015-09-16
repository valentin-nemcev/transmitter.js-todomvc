'use strict'

{inspect} = require 'util'

$ = require 'jquery'

window.JQuery = $
window.Transmitter = require 'transmitter'

{VisibilityToggleVar} = require './helpers'
{Todo, NonBlankTodoListChannel, TodoListWithCompleteChannel} = require './model'
{TodoListPersistenceChannel} = require './persistence'

HeaderView = require './views/header'
MainView   = require './views/main'
FooterView = require './views/footer'


class App extends Transmitter.Nodes.Record

  @defineLazy 'nonBlankTodoList', ->
    new Transmitter.Nodes.List()

  @defineLazy 'nonBlankTodoListChannel', ->
    new NonBlankTodoListChannel(@nonBlankTodoList, @todoList)


  @defineLazy 'todoList', ->
    new Transmitter.Nodes.List()


  @defineLazy 'todoListWithComplete', ->
    new Transmitter.Nodes.List()

  @defineLazy 'todoListWithCompleteChannel', ->
    new TodoListWithCompleteChannel(@todoList, @todoListWithComplete)


  @defineLazy 'todoListPersistenceVar', ->
    new Transmitter.Nodes.PropertyVariable(localStorage, 'todos-transmitter')

  @defineLazy 'todoListPersistenceChannel', ->
    new TodoListPersistenceChannel(@todoList, @todoListPersistenceVar)


  @defineLazy 'headerView', ->
    new HeaderView($('.header'))

  @defineLazy 'mainView', ->
    new MainView($('.main'))

  @defineLazy 'footerView', ->
    new FooterView($('.footer'))


  @defineLazy 'locationHash', ->
    new Transmitter.Browser.LocationHash()

  @defineLazy 'activeFilter', ->
    new Transmitter.Nodes.Variable()

  @defineLazy 'locationHashChannel', ->
    new Transmitter.Channels.SimpleChannel()
    .inBackwardDirection()
    .fromSource @locationHash
    .toTarget @activeFilter
    .withTransform (locationHashPayload) ->
      locationHashPayload.map (value) ->
        switch value
          when '#/active' then 'active'
          when '#/completed' then 'completed'
          else 'all'


  init: (tr) ->
    @nonBlankTodoListChannel.init(tr)
    @todoListWithCompleteChannel.init(tr)

    @todoListPersistenceChannel.init(tr)

    @headerView.init(tr)
    @headerView.createTodoListChannel(@todoList).init(tr)

    @mainView.init(tr)
    @mainView.createTodoListChannel(
      @todoList, @todoListWithComplete, @activeFilter).init(tr)

    @footerView.init(tr)
    @footerView.createTodoListChannel(
      @todoList, @todoListWithComplete, @activeFilter).init(tr)

    @locationHashChannel.init(tr)
    @locationHash.originate(tr)

    unless @todoListPersistenceVar.get()
      @todoListPersistenceVar.set(
        JSON.stringify([{title: 'Todo 1', completed: no},
        {title: 'Todo 2', completed: yes}])
      )

    @todoListPersistenceVar.originate(tr)

    # todo1 = new Todo().init(tr, label: 'Todo 1', isCompleted: no)
    # todo2 = new Todo().init(tr, label: 'Todo 2', isCompleted: yes)

    # todoList.init(tr, [todo1, todo2])


Element::inspect = -> '<' + @tagName + ' ... />'
$.Event::inspect = -> '[$Ev ' + @type + ' ... ]'
Event::inspect = -> '[Ev ' + @type + ' ... ]'

Transmitter.Transmission::loggingFilter = (msg) ->
  msg.match(/activeFilter/)
  # msg.match(/label(Input)?Var|MM/)

Transmitter.Transmission::loggingIsEnabled = no

app = new App()

Transmitter.startTransmission (tr) -> app.init(tr)
