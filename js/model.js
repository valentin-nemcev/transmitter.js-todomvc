import {inspect} from 'util';

import * as Transmitter from 'transmitter-framework/index.es';

export default class Todos {
  constructor() {
    this.todoList = new Transmitter.Nodes.List();

    this.nonBlankTodoList = new Transmitter.Nodes.List();
    this.nonBlankTodoListChannel =
      new NonBlankTodoListChannel(this.nonBlankTodoList, this.todoList);

    this.withComplete = new Transmitter.Nodes.List();
    this.todoListWithCompleteChannel =
      new TodoListWithCompleteChannel(this.todoList, this.withComplete);
  }

  init(tr) {
    this.nonBlankTodoListChannel.init(tr);
    this.todoListWithCompleteChannel.init(tr);
    return this;
  }

  create() {
    return new Todo();
  }
}


class Todo {
  inspect() {
    return '[Todo ' + (inspect(this.labelVar.get())) + ']';
  }

  constructor() {
    this.labelVar = new Transmitter.Nodes.Variable();
    this.isCompletedVar = new Transmitter.Nodes.Variable();
  }

  init(tr, defaults = {}) {
    const {label, isCompleted} = defaults;
    if (label != null) {
      this.labelVar.init(tr, label);
    }
    if (isCompleted != null) {
      this.isCompletedVar.init(tr, isCompleted);
    }
    return this;
  }
}


function nonBlank(str) {
  return !!str.trim();
}


class NonBlankTodoListChannel extends Transmitter.Channels.CompositeChannel {
  constructor(nonBlankTodoList, todoList) {
    super();
    this.nonBlankTodoList = nonBlankTodoList;
    this.todoList = todoList;

    this.nonBlankTodoChannelVar =
      new Transmitter.ChannelNodes.ChannelVariable();

    this.defineListChannel()
      .inForwardDirection()
      .withOrigin(this.nonBlankTodoList)
      .withDerived(this.todoList);

    this.defineSimpleChannel()
      .fromSource(this.todoList)
      .toConnectionTarget(this.nonBlankTodoChannelVar)
      .withTransform(
        (todoListPayload) =>
          todoListPayload.toSetVariable().map(
            (todos) =>
              this.createNonBlankTodoChannel(todos)
                .inBackwardDirection()
                .toTarget(this.nonBlankTodoList)
        )
      );
  }

  createNonBlankTodoChannel(todos) {
    new Transmitter.Channels.SimpleChannel()
      .fromDynamicSources(todos.map( (todo) => todo.labelVar ))
      .withTransform( (labelPayloads) =>
        Transmitter.Payloads.Variable.merge(labelPayloads).map(
          function(labels) {
            const results = [];
            for (let i = 0; i < labels.length; i++) {
              if (nonBlank(labels[i])) results.push(todos[i]);
            }
            return results;
          }
        )
      );
  }
}


class TodoListWithCompleteChannel
extends Transmitter.Channels.CompositeChannel {
  constructor(todoList, todoListWithComplete) {
    super();
    this.todoList = todoList;
    this.todoListWithComplete = todoListWithComplete;

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSource(this.todoListWithComplete)
      .toTarget(this.todoList)
      .withTransform(
        (todoListWithCompletePayload) =>
          todoListWithCompletePayload.map( ([todo]) => todo )
      );

    this.isCompletedList = new Transmitter.Nodes.List();
    this.isCompletedDynamicChannelVar =
      new Transmitter.ChannelNodes.DynamicChannelVariable('sources', () =>
        new Transmitter.Channels.SimpleChannel()
          .inForwardDirection()
          .toTarget(this.isCompletedList)
          .withTransform(
            (isCompletedPayload) => isCompletedPayload.flatten()
          )
        );

    this.defineSimpleChannel()
      .fromSource(this.todoList)
      .toConnectionTarget(this.isCompletedDynamicChannelVar)
      .withTransform(
        (todoListPayload) =>
          todoListPayload.map( (todo) => todo.isCompletedVar )
      );

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSources(this.todoList, this.isCompletedList)
      .toTarget(this.todoListWithComplete)
      .withTransform(
        ([todosPayload, isCompletedPayload]) =>
          todosPayload.zip(isCompletedPayload)
      );
  }
}
