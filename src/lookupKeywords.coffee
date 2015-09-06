_ = require 'lodash'
Promise = require 'when'
natural = require 'natural'
stopwords = require 'stopwords'

wordnet = new natural.WordNet()

numeric = /^[0-9]*$/
ars = /a|r|s/


module.exports = (words) ->
  Promise.all _.map words, (word) ->
    return unless word.length > 2
    return if numeric.test word
    return if -1 != stopwords.english.indexOf word
    deferred = Promise.defer()

    wordnet.lookup word, (results) ->
      neither = 0
      noun = 0
      verb = 0

      for result in results
        noun++ if result.pos == 'n'
        verb++ if result.pos == 'v'
        neither++ if ars.test result.pos
        if word == 'the'
          console.log 'the', word, result
      # console.log word, noun, verb, neither, results.length
      word = null if noun == 0 and neither > verb
      deferred.resolve word
    deferred.promise
  .then (keywords) ->
    _.compact keywords
