// inspect = require('util').inspect;

import $ from 'jquery';

import * as Transmitter from 'transmitter/index.es';

import Todos       from './model';
import TodoStorage from './storage';

import HeaderView  from './views/header';
import MainView    from './views/main';
import FooterView  from './views/footer';

class App {
  constructor() {
    this.todos = new Todos();
    this.todoStorage = new TodoStorage('todos-transmitter');

    this.headerView = new HeaderView($('.header'));
    this.mainView = new MainView($('.main'));
    this.footerView = new FooterView($('.footer'));

    this.locationHash = new Transmitter.Browser.LocationHash();
    this.activeFilter = new Transmitter.Nodes.Variable();
    this.locationHashChannel = new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource(this.locationHash)
      .toTarget(this.activeFilter)
      .withTransform( (locationHashPayload) =>
        locationHashPayload.map( (value) => {
          switch (value) {
          case '#/active':
            return 'active';
          case '#/completed':
            return 'completed';
          default:
            return 'all';
          }
        })
      );
  }

  init(tr) {
    this.todos.init(tr);

    this.todoStorage.setDefault([
      {
        title: 'Todo 1',
        completed: false
      }, {
        title: 'Todo 2',
        completed: true
      }
    ]);

    this.todoStorage.createTodosChannel(this.todos).init(tr);
    this.todoStorage.load(tr);

    this.headerView.init(tr);
    this.headerView.createTodosChannel(this.todos).init(tr);

    this.mainView.init(tr);
    this.mainView.createTodosChannel(this.todos, this.activeFilter).init(tr);

    this.footerView.init(tr);
    this.footerView.createTodosChannel(this.todos, this.activeFilter).init(tr);

    this.locationHashChannel.init(tr);
    this.locationHash.originate(tr);

    return this;
  }
}

Element.prototype.inspect = function() {
  return '<' + this.tagName + ' ... />';
};

$.Event.prototype.inspect = function() {
  return '[$Ev ' + this.type + ' ... ]';
};

Event.prototype.inspect = function() {
  return '[Ev ' + this.type + ' ... ]';
};

Transmitter.Transmission.prototype.loggingFilter = function() {};

Transmitter.Transmission.prototype.loggingIsEnabled = false;

const app = new App();

Transmitter.startTransmission( (tr) => app.init(tr) );
