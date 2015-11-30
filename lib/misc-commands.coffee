# The commands defined in this file is processed by operationStack.
# The commands which is not well fit to one of Motion, TextObject, Operator
#  goes here.
{Range} = require 'atom'
Base = require './base'
swrap = require './selection-wrapper'
settings = require './settings'

{isLinewiseRange} = require './utils'

class Misc extends Base
  @extend(false)
  complete: true

  constructor: ->
    super
    @initialize?()

class ReverseSelections extends Misc
  @extend()
  execute: ->
    lastSelection = @editor.getLastSelection()
    swrap(lastSelection).reverse()
    reversed = lastSelection.isReversed()
    for s in @editor.getSelections() when not s.isLastSelection()
      swrap(s).setReversedState(reversed)

class SelectLatestChange extends Misc
  @extend()
  complete: true

  execute: ->
    start = @vimState.mark.get('[')
    end = @vimState.mark.get(']')
    if start? and end?
      range = new Range(start, end)
      @editor.setSelectedBufferRange(range)
      submode = if isLinewiseRange(range) then 'linewise' else 'characterwise'
      @vimState.activate('visual', submode)

class Undo extends Misc
  @extend()
  execute: ->
    @editor.undo()
    @finish()

  finish: ->
    s.clear() for s in @editor.getSelections()
    @vimState.activate('normal')

class Redo extends Undo
  @extend()

  flash: (range) ->
    @vimState.flasher.flash range,
      class: 'vim-mode-plus-flash'
      timeout: settings.get('flashOnRedoDuration')

  withFlash: (fn) ->
    needFlash = settings.get('flashOnRedo')
    setToStart = settings.get('setCursorToStartOfChangeOnRedo')
    unless (needFlash or setToStart)
      fn()
      return

    [start, end] = []
    disposable = @editor.getBuffer().onDidChange ({newRange}) ->
      start ?= newRange.start
      # Update only end point
      if needFlash
        end = newRange.end
      else
        disposable.dispose()
    fn()
    if setToStart and start
      @editor.setCursorBufferPosition(start)
    if needFlash and start and end
      disposable.dispose()
      @flash(new Range(start, end))

  execute: ->
    @withFlash =>
      @editor.redo()
    @finish()
