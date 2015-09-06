_ = require 'lodash'
natural = require 'natural'
Promise = require 'when'

lookupKeywords = require './lookupKeywords'

NGrams = natural.NGrams
tokenizer = new natural.TreebankWordTokenizer()
natural.LancasterStemmer.attach()

url_pattern = /\(?\bhttps?:\/\/[-A-Za-z0-9+&@#/%?=~_()|!:,.;]*[-A-Za-z0-9+&@#/%=~_()|]/gi
hash_pattern = /#[a-zA-Z_0-9]*/gi
at_pattern = /(^|\s)@[-A-Za-z0-9_]+(\s|$)/gi
alpha_pattern =  /[^a-z^A-Z^0-9^-^_]/gi

urls = (str) ->
  str.match(url_pattern) ? []

hashtags = (str) ->
  str.match(hash_pattern) ? []

getDomains = (str) ->
  _.map urls(str), (url) ->
    domain = url.substr url.indexOf('//') + 2
    domain.substring(0, domain.indexOf('/')) ? domain

breakString = (str) ->
  # console.log 'break', str
  str
  .replace url_pattern, '|'
  .replace hash_pattern, ''
  .replace at_pattern, '$1|$2'
  .replace /[^a-z^A-Z^0-9^-^_|]/gi, ' '
  .replace /(^[\s]+)|([\s]+$)/g, ''
  .replace /[\s]+/g, ' '

module.exports = tokenize = (message) ->
  keywords = []
  query = []

  keywords = keywords.concat getDomains message
  keywords = keywords.concat _.map hashtags(message), (hash) ->
    hash.substring 1

  message = breakString message
  # console.log "break? [#{message}]", keywords.join '|'

  if /\|/.test message
    return Promise.all _.map message.split('|'), (sub) ->
      sub = sub
        .replace /(^[\s]+)|([\s]+$)/g, ''
      if sub.length > 0
        tokenize sub
      else
        null
    .then (results) ->
      _keywords = _ results
        .pluck 'keywords'
        .compact()
        .flatten()
        .uniq()
        .value()
        .concat keywords
      _query = _ results
        .pluck 'query'
        .compact()
        .flatten()
        .uniq()
        .value()
      keywords: _keywords
      query: _query

  message = message
    .replace /[\s]+/g, ' '
    .replace /(^[\s]+)|([\s]+$)/g, ''

  words = tokenizer.tokenize message
  # words = message.split ' '

  maxNGram = words.length
  maxNGram = 4 if maxNGram > 4
  if maxNGram >= 2
    for len in [maxNGram..2] by -1
      #ngrams = NGrams.ngrams words, len
      ngrams = []
      for start in [0..(words.length-len)] by 1
        ngrams.push words.slice start, start + len
      for phrase in ngrams
        query.push phrase.join ' '
        query.push phrase.join ''

  lookupKeywords words
  .then (_keywords) ->
    keywords: keywords.concat _keywords
    query: query
