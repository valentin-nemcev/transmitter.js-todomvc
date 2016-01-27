import {inspect} from 'util';

import * as Transmitter from 'transmitter-framework/index.es';

export default class Todos {
  constructor() {
    this.todoSet = new Transmitter.Nodes.OrderedSetNode();

    this.nonBlankTodoSet = new Transmitter.Nodes.OrderedSetNode();
    this.nonBlankTodoListChannel =
      new NonBlankTodoListChannel(this.nonBlankTodoSet, this.todoSet);

    this.withComplete = new Transmitter.Nodes.ListNode();
    this.todoListWithCompleteChannel =
      new TodoListWithCompleteChannel(this.todoSet, this.withComplete);
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
    this.labelValue = new Transmitter.Nodes.ValueNode();
    this.isCompletedValue = new Transmitter.Nodes.ValueNode();
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
  constructor(nonBlankTodoSet, todoSet) {
    super();
    this.nonBlankTodoSet = nonBlankTodoSet;
    this.todoSet = todoSet;

    this.nonBlankTodoChannelValue =
      new Transmitter.ChannelNodes.ChannelValue();

    this.defineBidirectionalChannel()
      .inForwardDirection()
      .withOriginDerived(this.nonBlankTodoSet, this.todoSet);

    this.defineNestedSimpleChannel()
      .fromSource(this.todoSet)
      .toChannelTarget(this.nonBlankTodoChannelValue)
      .withTransform(
        (todoListPayload) =>
          todoListPayload.joinValues().map(
            (todos) =>
              this.createNonBlankTodoChannel(todos)
                .toTarget(this.nonBlankTodoSet)
        )
      );
  }

  createNonBlankTodoChannel(todos) {
    return new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromDynamicSources(todos.map( (todo) => todo.labelValue ))
      .withTransform( (labelPayloads) =>
        Transmitter.zipPayloads(labelPayloads).map(
          function(labels) {
            const results = [];
            for (let i = 0; i < labels.length; i++) {
              if (nonBlank(labels[i])) results.push(todos[i]);
            }
            return results;
          }
        ).splitValues()
      );
  }
}


class TodoListWithCompleteChannel
extends Transmitter.Channels.CompositeChannel {
  constructor(todoSet, todoListWithComplete) {
    super();
    this.todoSet = todoSet;
    this.todoListWithComplete = todoListWithComplete;

    this.defineSimpleChannel()
      .inBackwardDirection()
      .fromSource(this.todoListWithComplete)
      .toTarget(this.todoSet)
      .withTransform(
        (todoListWithCompletePayload) =>
          todoListWithCompletePayload.map( ([todo]) => todo )
      );

    this.isCompletedList = new Transmitter.Nodes.ListNode();
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
      .fromSource(this.todoSet)
      .toChannelTarget(this.isCompletedDynamicChannelValue)
      .withTransform(
        (todoListPayload) =>
          todoListPayload.map( (todo) => todo.isCompletedValue )
      );

    this.defineSimpleChannel()
      .inForwardDirection()
      .fromSources(this.todoSet, this.isCompletedList)
      .toTarget(this.todoListWithComplete)
      .withTransform(
        ([todosPayload, isCompletedPayload]) =>
          todosPayload.zip(isCompletedPayload)
      );
  }
}
