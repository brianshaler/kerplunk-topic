React = require 'react'

{DOM} = React

module.exports = React.createFactory React.createClass
  render: ->
    DOM.pre null,
      JSON.stringify @props.item, null, 2
