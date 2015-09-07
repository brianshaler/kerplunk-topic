_ = require 'lodash'
Promise = require 'when'

###
# Topic schema
###

module.exports = (mongoose) ->
  Schema = mongoose.Schema
  ObjectId = Schema.ObjectId

  TopicSchema = new Schema
    text:
      type: String
      required: true
      index:
        unique: true
    attributes:
      type: Object
      default: -> {}
    instances:
      type: Number
      default: 0
    updatedAt:
      type: Date
      default: Date.now
    createdAt:
      type: Date
      default: Date.now

  TopicSchema.statics.getOrCreateArray = (arr) ->
    return Promise.resolve([]) unless arr?.length > 0
    mpromise = @where
      text:
        '$in': arr
    .find()
    Promise(mpromise).then (topics) =>
      Promise.all _.map arr, (topic) =>
        existing = _.find topics, (existingTopic) ->
          existingTopic.text == topic
        return existing if existing
        @getOrCreate topic

  TopicSchema.statics.getOrCreate = (obj, retry = true) ->
    Topic = mongoose.model 'Topic'
    if typeof obj is 'string'
      obj =
        text: obj

    return Promise.reject new Error 'Bad input' unless obj.text?.length > 0

    mpromise = Topic
    .where
      text: obj.text
    .findOne()
    Promise(mpromise).then (topic) ->
      return topic if topic
      obj.attributes =
        rated: false
      topic = new Topic obj
      topic.markModified 'attributes'
      Promise topic.save()
      .catch (err) ->
        console.log 'topic save error', err if err
        throw err unless retry == true
        Promise.promise (resolve, reject) ->
          setTimeout ->
            resolve Topic.getOrCreate obj, false
          , 100 + Math.random() * 100
      .then -> topic

  mongoose.model 'Topic', TopicSchema
