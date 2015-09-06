_ = require 'lodash'
Promise = require 'when'

TopicSchema = require './models/Topic'
tokenize = require './tokenize'

findTopicsFromKeywords = (Topic, keywords) ->
  deferred = Promise.defer()
  Topic
  .where
    text:
      '$in': keywords
  .find (err, topics) ->
    return deferred.reject err if err
    deferred.resolve topics
  deferred.promise

module.exports = (System) ->
  Topic = System.registerModel 'Topic', TopicSchema
  ActivityItem = System.getModel 'ActivityItem'

  saveModel = (item) ->
    deferred = Promise.defer()
    item.save (err) ->
      return deferred.reject err if err
      where =
        'attributes.topic': item._id
      delta =
        'attributes.rated': false
      options =
        multi: true
      ActivityItem
      .update where, delta, options, (err, updateResult) ->
        console.log 'reset ratings', err, updateResult
        deferred.resolve item
    deferred.promise

  addTopics = (item) ->
    # console.log 'add topics', item._id ? item.message
    if item.attributes?.topic?
      # console.log 'already has topics'
      return item
    unless item.message?.length > 0
      console.log 'no message?'
      return item


    tokenize item.message
    .then (result) ->
      {keywords, query} = result
      Promise.all [
        Topic.getOrCreateArray result.keywords
        findTopicsFromKeywords Topic, result.query
      ]
    .then (topics) ->
      topics = _.flatten topics
      # console.log 'topics', _.pluck topics, 'text'
      item.attributes = {} unless item.attributes
      item.attributes.topic = _.map topics, (topic) ->
        topic._id ? topic
      item

  routes:
    admin:
      '/admin/topic/:id/show': 'show'
      '/admin/topic/search': 'search'

  handlers:
    show: (req, res, next) ->
      Topic
      .where
        _id: req.params.id
      .findOne (err, item) ->
        return next err if err
        res.render 'show',
          data: [item]
    search: (req, res, next) ->
      text = req.query.text
      return next() unless text?.length > 0
      Topic
      .where
        text: text
      .findOne (err, item) ->
        return next err if err
        return next() unless item
        res.render 'show',
          data: [item]

  globals:
    public:
      activityItem:
        populate:
          topic: 'Topic'

  events:
    topic:
      save:
        do: saveModel
    activityItem:
      save:
        pre: addTopics

  models:
    Topic: Topic
