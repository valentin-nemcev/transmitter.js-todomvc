import {inspect} from 'util';

import $ from 'jquery';

import * as Transmitter from 'transmitter-framework/index.es';

import {
  getKeycodeMatcher,
  VisibilityToggleValue,
  ClassToggleValue,
} from '../helpers';

class EditStateChannel extends Transmitter.Channels.CompositeChannel {

  constructor(todoView) {
    super();
    this.todoView = todoView;

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSource(this.todoView.startEditEvt)
      .toTarget(this.todoView.editStateValue)
      .withTransform(
        (startEditPayload) => startEditPayload.map( () => true )
      );

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSource(this.todoView.acceptEditEvt)
      .toTarget(this.todoView.editStateValue)
      .withTransform(
        (acceptEditPayload) => acceptEditPayload.map( () => false )
      );

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSource(this.todoView.rejectEditEvt)
      .toTarget(this.todoView.editStateValue)
      .withTransform(
        (rejectEditPayload) => rejectEditPayload.map( () => false )
      );
  }
}


class TodoView {

  inspect() {
    return '[TodoView ' + inspect(this.todo.labelValue.get()) + ']';
  }

  constructor(todo) {
    this.todo = todo;
    this.$element = $('<li/>').append(
      $('<div/>', {class: 'view'})
      .append(
        this.$checkbox = $('<input/>', {class: 'toggle', type: 'checkbox'}),
        this.$label = $('<label/>'),
        this.$destroy = $('<button/>', {class: 'destroy'})
      ),
      this.$edit = $('<input/>', {class: 'edit'})
    );

    this.labelValue =
      new Transmitter.DOMElement.TextValue(this.$label[0]);

    this.labelInputValue =
      new Transmitter.DOMElement.InputValueValue(this.$edit[0]);

    this.isCompletedInputValue =
      new Transmitter.DOMElement.CheckboxStateValue(this.$checkbox[0]);

    this.labelDblclickEvt =
      new Transmitter.DOMElement.DOMEvent(this.$label[0], 'dblclick');

    this.inputKeypressEvt =
      new Transmitter.DOMElement.DOMEvent(this.$edit[0], 'keyup');

    this.destroyClickEvt =
      new Transmitter.DOMElement.DOMEvent(this.$destroy[0], 'click');

    this.isCompletedClassValue = new ClassToggleValue(this.$element, 'completed');
    this.editStateValue = new ClassToggleValue(this.$element, 'editing');

    this.startEditEvt = this.labelDblclickEvt;
    this.acceptEditEvt = new Transmitter.Nodes.RelayNode();
    this.rejectEditEvt = new Transmitter.Nodes.RelayNode();

    this.acceptEditChannel = new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource(this.inputKeypressEvt)
      .toTarget(this.acceptEditEvt)
      .withTransform(getKeycodeMatcher('enter'));

    this.rejectEditChannel = new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource(this.inputKeypressEvt)
      .toTarget(this.rejectEditEvt)
      .withTransform(getKeycodeMatcher('esc'));
  }

  init(tr) {
    this.editStateValue.init(tr, false);
    this.acceptEditChannel.init(tr);
    this.rejectEditChannel.init(tr);
    this.editStateChannel = new EditStateChannel(this).init(tr);
    return this;
  }

  createRemoveTodoChannel() {
    return new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource(this.destroyClickEvt)
      .withTransform(
        (destroyClickPayload) =>
          destroyClickPayload.map( () => this.todo ).toRemoveListElement()
      );
  }
}


class TodoViewChannel extends Transmitter.Channels.CompositeChannel {

  inspect() {
    return this.todo.inspect() + '-' + this.todoView.inspect();
  }

  constructor(todo, todoView) {
    super();
    this.todo = todo;
    this.todoView = todoView;

    this.defineValueChannel()
      .withOrigin(this.todo.labelValue)
      .withDerived(this.todoView.labelValue);

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSources(this.todoView.labelInputValue, this.todoView.acceptEditEvt)
      .toTarget(this.todo.labelValue)
      .withTransform(
        ([labelPayload, acceptPayload]) =>
          labelPayload.replaceByNoop(acceptPayload)
      );

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSources(
        this.todo.labelValue,
        this.todoView.startEditEvt,
        this.todoView.rejectEditEvt
      )
      .toTarget(this.todoView.labelInputValue)
      .withTransform(
        ([labelPayload, startPayload, rejectPayload]) =>
          labelPayload.replaceByNoop(startPayload.replaceNoopBy(rejectPayload))
      );

    this.defineValueChannel()
      .withOrigin(this.todo.isCompletedValue)
      .withDerived(this.todoView.isCompletedInputValue);

    this.defineValueChannel()
      .inForwardDirection()
      .withOrigin(this.todo.isCompletedValue)
      .withDerived(this.todoView.isCompletedClassValue);
  }
}


export default class MainView {
  constructor($element) {
    this.$element = $element;

    this.viewList = new Transmitter.Nodes.List();
    this.elementList =
      new Transmitter.DOMElement.ChildrenList(
        this.$element.find('.todo-list')[0]
      );

    this.viewElementListChannel =
      new Transmitter.Channels.SimpleChannel()
        .inForwardDirection()
        .fromSource(this.viewList)
        .toTarget(this.elementList)
        .withTransform(
          (views) =>
          views.updateMatching(
            (view) => view.$element[0],
            (view, element) => view.$element[0] === element
          )
        );

    const $toggleAll = this.$element.find('.toggle-all');
    this.toggleAllCheckboxValue =
      new Transmitter.DOMElement.CheckboxStateValue($toggleAll[0]);

    this.toggleAllChangeEvt =
      new Transmitter.DOMElement.DOMEvent($toggleAll[0], 'click');

    this.isVisibleValue = new VisibilityToggleValue(this.$element);
  }

  init(tr) {
    return this.viewElementListChannel.init(tr);
  }

  createTodosChannel(todos, activeFilter) {
    return new MainViewChannel(
      todos.todoList, todos.withComplete, this, activeFilter
    );
  }
}


class ToggleAllChannel extends Transmitter.Channels.CompositeChannel {

  constructor(
    todoList,
    todoListWithComplete,
    toggleAllCheckboxValue,
    toggleAllChangeEvt
  ) {
    super();
    this.todoList = todoList;
    this.todoListWithComplete = todoListWithComplete;
    this.toggleAllCheckboxValue = toggleAllCheckboxValue;
    this.toggleAllChangeEvt = toggleAllChangeEvt;

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSource(this.todoListWithComplete)
      .toTarget(this.toggleAllCheckboxValue)
      .withTransform(
        (todoListWithCompletePayload) =>
          todoListWithCompletePayload.toSetValue().map(
            (todos) => todos.every( ([, isCompleted]) => isCompleted )
          )
      );

    this.toggleAllDynamicChannelValue =
      new Transmitter.ChannelNodes.DynamicChannelValue(
        'targets',
        () =>
          new Transmitter.Channels.SimpleChannel()
            .inBackwardDirection()
            .fromSources(this.toggleAllCheckboxValue, this.toggleAllChangeEvt)
            .withTransform(
              ([isCompletedPayload, changePayload],
               isCompletedListPayload) => {
                const payload = isCompletedPayload
                  .replaceByNoop(changePayload)
                  .map( (state) => !state );
                return isCompletedListPayload.map( () => payload );
              }
            )
      );

    this.defineSimpleChannel()
      .fromSource(this.todoList)
      .toConnectionTarget(this.toggleAllDynamicChannelValue)
      .withTransform(
        (todoListPayload) => {
          if (todoListPayload == null) return null;
          return todoListPayload.map( ({isCompletedValue}) => isCompletedValue );
        }
      );
  }
}


class MainViewChannel extends Transmitter.Channels.CompositeChannel {

  inspect() {
    return this.todoList.inspect() + '-' + this.todoListView.inspect();
  }

  constructor(todoList, todoListWithComplete, todoListView, activeFilter) {
    super();
    this.todoList = todoList;
    this.todoListWithComplete = todoListWithComplete;
    this.todoListView = todoListView;
    this.activeFilter = activeFilter;

    this.removeTodoChannelList = new Transmitter.ChannelNodes.ChannelList();
    this.filteredTodoList = new Transmitter.Nodes.List();

    this.defineSimpleChannel()
      .fromSource(this.todoListView.viewList)
      .toConnectionTarget(this.removeTodoChannelList)
      .withTransform(
        (todoViews) =>
          todoViews != null
            ? todoViews.map(
              (todoView) =>
                todoView.createRemoveTodoChannel().toTarget(this.todoList)
            )
            : null
      );

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSources(this.todoListWithComplete, this.activeFilter)
      .toTarget(this.filteredTodoList)
      .withTransform(
        ([todoListPayload, activeFilterPayload]) => {
          const filter = activeFilterPayload.get();
          return todoListPayload
            .filter(
              ([, isCompleted]) => {
                switch (filter) {
                case 'active':
                  return !isCompleted;
                case 'completed':
                  return isCompleted;
                default:
                  return true;
                }
              }
            )
            .map( ([todo]) => todo );
        }
      );

    this.defineListChannel()
      .inForwardDirection()
      .withOrigin(this.filteredTodoList)
      .withMapOrigin(
        (todo, tr) => new TodoView(todo).init(tr)
      )
      .withDerived(this.todoListView.viewList)
      .withMatchOriginDerived(
        (todo, todoView) => todo === todoView.todo
      )
      .withMatchOriginDerivedChannel(
        (todo, todoView, channel) =>
          channel.todo === todo && channel.todoView === todoView
      )
      .withOriginDerivedChannel(
        (todo, todoView) => new TodoViewChannel(todo, todoView)
      );

    this.addChannel(
      new ToggleAllChannel(
        this.todoList,
        this.todoListWithComplete,
        this.todoListView.toggleAllCheckboxValue,
        this.todoListView.toggleAllChangeEvt
      )
    );

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSource(this.todoList)
      .toTarget(this.todoListView.isVisibleValue)
      .withTransform(
        (todoListPayload) =>
          todoListPayload.toSetValue().map( (todos) => todos.length > 0 )
      );
  }
}
