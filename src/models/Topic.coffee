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
    deferred = Promise.defer()
    return Promise.resolve() unless arr?.length > 0
    @where
      text:
        '$in': arr
    .find (err, topics) =>
      return deferred.reject err if err
      deferred.resolve Promise.all _.map arr, (topic) =>
        existing = _.find topics, (existingTopic) ->
          existingTopic.text == topic
        return existing if existing
        @getOrCreate topic
    deferred.promise

  TopicSchema.statics.getOrCreate = (obj, retry = true) ->
    Topic = mongoose.model 'Topic'
    deferred = Promise.defer()
    if typeof obj is 'string'
      obj =
        text: obj

    return deferred.reject 'Bad input' unless obj.text?.length > 0

    Topic
    .where
      text: obj.text
    .findOne (err, topic) ->
      return deferred.reject err if err
      return deferred.resolve topic if topic
      obj.attributes =
        rated: false
      topic = new Topic obj
      topic.markModified 'attributes'
      topic.save (err) ->
        if err
          console.log 'topic save error', err if err
          return deferred.reject err unless retry == true
          setTimeout ->
            deferred.resolve Topic.getOrCreate obj, false
          , 100 + Math.random() * 100
          return
        deferred.resolve topic
    deferred.promise

  # TopicSchema.pre 'save', (next) ->
  #   ActivityItem = mongoose.model 'ActivityItem'
  #
  #   @calculateRatings()
  #
  #   HOUR_AGO = new Date Date.now() - 3600*1000
  #   DAY_AGO = new Date Date.now() - 86400*1000
  #
  #   ActivityItem.count {
  #     topics: @id,
  #     postedAt: {'$gt': new Date(Date.now() - 99*86400*1000)}
  #   }, (err, count) =>
  #     if err or !count
  #       count = 0
  #     @instances = count
  #
  #     if !@updatedAt
  #       @updatedAt = new Date()
  #     lastUpdate = @updatedAt
  #     @updatedAt = new Date()
  #
  #     # only analyze unique user activity every ~2 mins
  #     if lastUpdate.getTime() > @updatedAt.getTime() - .60*1000
  #       return next()
  #     else
  #       command =
  #         group:
  #           ns: 'activityitems' # the collection to query
  #           cond: # active.end must be in the future
  #             topics: @_id
  #             postedAt:
  #               '$gt': DAY_AGO
  #           initial: # initialize any count object properties
  #             cnt: 0
  #             postedAt: new Date(0)
  #           # the reduce function which specifies an iterated 'doc' within the collection and 'out' count object *Note: 'reduce' must prefice by $
  #           '$reduce': 'function(doc, out){ out.cnt++; out.postedAt = doc.postedAt; }'
  #           key: #fields to group by
  #             user: 1
  #       mongoose.connection.db.executeDbCommand command, (err, dbres) =>
  #         if err
  #           #console.log(err);
  #           return next()
  #         else
  #           #console.log(dbres);
  #           if dbres and dbres.documents and dbres.documents.length >= 1 and dbres.documents[0].retval
  #             @activity_24h = dbres.documents[0].retval.length
  #             recent = []
  #             dbres.documents[0].retval.forEach (act) =>
  #               if act.postedAt > HOUR_AGO
  #                 recent.push act
  #             @activity_1h = recent.length
  #             #console.log(dbres.documents[0].retval);
  #         return next()
  #
  # TopicSchema.methods.initRatings = () ->
  #   defaults =
  #     overall: 0
  #     likes: 0
  #     dislikes: 0
  #
  #   @ratings = {} unless typeof @ratings == 'object'
  #   for k, v of defaults
  #     @ratings[k] = v unless typeof @ratings[k] == 'number'
  #   @
  #
  # TopicSchema.methods.calculateRatings = () ->
  #   @initRatings() # make sure ratings exist
  #   likes = @ratings.likes
  #   dislikes = @ratings.dislikes
  #
  #   # unanimous square
  #   if likes == 0 or dislikes == 0
  #     likes *= likes
  #     dislikes *= dislikes
  #
  #   neutrality = 0
  #   matched = if likes < dislikes then likes else dislikes
  #   if matched > 0
  #     neutrality = 2*matched/(likes+dislikes)
  #   #console.log "#{matched}/(#{likes}+#{dislikes}) = #{neutrality}"
  #
  #   # well-trained
  #   experience = (n) ->
  #     (Math.sin(-Math.PI/2 + Math.PI*(1 - Math.pow(1 + n/2, -0.5)))+1)/2
  #   # console.log "#{likes+dislikes} => #{experience(likes+dislikes)}"
  #
  #   likes2 = if likes > dislikes then likes-dislikes else 0
  #   dislikes2 = if dislikes > likes then dislikes-likes else 0
  #
  #   likes = likes2 * experience(likes+dislikes)
  #   dislikes = dislikes2 * experience(dislikes*.7)
  #
  #   factors = []
  #   likeness = 0
  #   thumbs = dislikes + likes
  #   percent = if thumbs < 100 then thumbs else 100
  #   percent = if percent > 10 then percent else percent + (10-percent)*.5
  #   if dislikes > likes
  #     likeness = -(dislikes-likes)/dislikes*percent
  #   if likes > dislikes
  #     likeness = (likes-dislikes)/likes*percent
  #
  #   likeness = likes*experience(thumbs*100) - dislikes*experience(thumbs*100)
  #   likeness *= (1-neutrality)
  #   if likeness != 0
  #     factors[0] = likeness
  #   sum = 0
  #   for k, val in @ratings
  #     if parseFloat(@ratings[k]) != 0 and k != 'overall' and k != 'likes' and k != 'dislikes'
  #       factors[factors.length] = parseFloat @ratings[k]
  #   factors.forEach (f) => sum += f
  #   @ratings.overall = if factors.length > 0 then sum / factors.length else 0
  #   @
  #
  # TopicSchema.methods.like = () ->
  #   @initRatings()
  #   @ratings.likes++
  #   @calculateRatings()
  #   @
  #
  # TopicSchema.methods.dislike = () ->
  #   @initRatings()
  #   @ratings.dislikes++
  #   @calculateRatings()
  #   @

  mongoose.model 'Topic', TopicSchema
