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
    return '[Todo ' + (inspect(this.labelValue.get())) + ']';
  }

  constructor() {
    this.labelValue = new Transmitter.Nodes.Value();
    this.isCompletedValue = new Transmitter.Nodes.Value();
  }

  init(tr, {label, isCompleted} = {}) {
    this.labelValue.set(label).init(tr);
    this.isCompletedValue.set(isCompleted).init(tr);
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

    this.nonBlankTodoChannelValue =
      new Transmitter.ChannelNodes.ChannelValue();

    this.defineBidirectionalChannel()
      .inForwardDirection()
      .withOriginDerived(this.nonBlankTodoList, this.todoList);

    this.defineNestedSimpleChannel()
      .fromSource(this.todoList)
      .toChannelTarget(this.nonBlankTodoChannelValue)
      .withTransform(
        (todoListPayload) =>
          todoListPayload.toValue().map(
            (todos) =>
              this.createNonBlankTodoChannel(todos)
                .toTarget(this.nonBlankTodoList)
        )
      );
  }

  createNonBlankTodoChannel(todos) {
    return new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromDynamicSources(todos.map( (todo) => todo.labelValue ))
      .withTransform( (labelPayloads) =>
        Transmitter.mergeValuePayloads(labelPayloads).map(
          function(labels) {
            const results = [];
            for (let i = 0; i < labels.length; i++) {
              if (nonBlank(labels[i])) results.push(todos[i]);
            }
            return results;
          }
        ).toList()
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
    this.isCompletedDynamicChannelValue =
      new Transmitter.ChannelNodes.DynamicListChannelValue(
        'sources',
        (sources) =>
          new Transmitter.Channels.SimpleChannel()
            .inForwardDirection()
            .fromDynamicSources(sources)
            .toTarget(this.isCompletedList)
            .withTransform(
              (isCompletedPayload) => isCompletedPayload.flatten()
            )
        );

    this.defineNestedSimpleChannel()
      .fromSource(this.todoList)
      .toChannelTarget(this.isCompletedDynamicChannelValue)
      .withTransform(
        (todoListPayload) =>
          todoListPayload.map( (todo) => todo.isCompletedValue )
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
