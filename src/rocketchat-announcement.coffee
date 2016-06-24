# Description
#   A hubot script to make DM announcements to Rocket.Chat users.
#
# Configuration:
#   TODO: Add role permissions config for creating announcements
#
# Commands:
#   hubot announce "<message>" - Sends message to all users
#
# Notes:
#   As well as commands above, announcements method can be directly called by custom responds
#   e.g. TODO: method usage example
#
#   The intention is to provide a method of read-only communication to a large group,
#   without polluting public channels or starting defacto group chats. Its the BCC of DM.
#
# Author:
#   Tim Kinnane @ 4thParty
#
# Todos:
#   TODO: Accept second parameter <who> to target group
#   TODO: Add scheduling commands
#         e.g. hubot don't send me anything below <level>
#   TODO: Save announcements in brain DB with ID so sent message status can be retrieved
#   TODO: Add report command to reply with announcement analytics
#         e.g. hubot announcement report 19
#           <message> (excerpt) was sent to 245 users last Tuesday at 4:12pm
#           122 received it successfully. 41 have been online, but didn't open announcements.
#           82 users have not been online since it was sent.

# Use hubot conversation to branch inputs
Conversation = require 'hubot-conversation'
Q = require 'q'
_ = require 'underscore'

module.exports = (robot) ->
  robotName = robot.alias or robot.name
  switchBoard = new Conversation robot

  # Get robot brain collection pointer when DB merged in
  robot.brain.on 'loaded', =>
    if robot.brain.get('announcements') is null
      robot.brain.set 'announcements', []

  # Remove the robot name to isolate the matched words
  stripRobotName = (match) ->
    nameStart = if match.charAt(0) is '@' then 1 else 0
    if match.indexOf(robot.name) is nameStart then named = robot.name
    else if match.indexOf(robot.alias) is nameStart then named = robot.alias
    else if match.indexOf('Hubot') is nameStart then named = 'Hubot' # dialog prepends hubot (this is dumb)
    else if match.indexOf('hubot') is nameStart then named = 'hubot'
    nameLength = if named is undefined then 0 else nameStart + named.length
    if match.charAt(nameLength) is ':' then nameLength++
    return match.substring(nameLength).trim()

  # Announcement object instantiated from a given message
  class Announcement

    constructor: (@msg, lvl=null, txt=null) ->
      @original = @msg.envelope
      @level = lvl or stripRobotName @msg.match[0] # get matched word in command
      @DMs = []

      # Remove command from message text, validate then append source
      @text = txt or @original.message.text.substring @msg.match[0].length # get message sans matched word
      @text = "#{ @text.trim() }"
      if @text is ""
        robot.logger.error "No text in announcement after trim."
        @msg.reply "Sorry, there's no text content in that message. Please try again."
        return false

      robot.logger.debug "Creating #{ @level } announcement with message '#{ @text }'"
      @text += "\n_#{ @level } sent by_ @#{ @original.user.name }"

      return @ # Return thyself

    # Get the users for the specified target group (defaults to all)
    setTarget: (@target) ->
      switch @target
        when 'online' then botRequest = robot.adapter.callMethod('botRequest', 'onlineIDs')
        else botRequest = robot.adapter.callMethod('botRequest', 'allIDs')

      return botRequest
      .then (result) =>
        @users = result
        robot.logger.info "Announcement targeted at #{ @users.length } users."
        if @users.length < 1
          throw 'No users'
      .catch (error) =>
        robot.logger.error "User request returned error: #{ error }"
        msg.reply "There's been an error. I can't get target users for the announcement."

    # Get addresses for each user's DM room
    addressDMs: () ->
      robot.logger.debug "Announcement addrressed to #{ @users.length } users."
      return Q.all _.map @users, (user) =>
        # robot.logger.debug "Requesting DM ID for #{ user.name }"
        Q.when robot.adapter.chatdriver.getDirectMessageRoomId(user.name), (result) =>
          robot.logger.debug "Addressing announcement DM to #{ result.rid } (#{ user.name })"
          @DMs.push { "room": result.rid, "user": user }
        , (error) ->
          robot.logger.error "Error getting DM Room ID for #{ user.name }: #{ JSON.stringify error }"

    # Send DM to all target users
    # NB: Q.fcall used because sendMessageByRoomId does not return a promise
    sendDMs: () ->
      robot.logger.debug "Sending #{ @DMs.length } direct messages..."
      return Q.all _.map @DMs, (DM) =>
        # robot.logger.debug "Sending announcement to room #{ DM.room }"
        try Q.fcall () => robot.adapter.chatdriver.sendMessageByRoomId @text, DM.room
        catch e then robot.logger.error "Error sending direct message to #{ DM.room }: #{ e }"
        finally return true # carry on to next
      .catch (error) =>
        robot.logger.error "Error sending direct messages: #{ JSON.stringify error }"

    # Save announcement in robot brain and persist
    save: () ->
      # @msg.robot.brain.set 'announcements', @Announcement
      # @msg.robot.brain.save()

    # Send announcement as DM to all in target group
    sendTo: (target) ->
      # TODO: take target from msg parameters
      return @setTarget(target)
      .then () =>
        @addressDMs()
      .then () =>
        @sendDMs()

  #--------------------------------------------------------
  # LISTENERS ---------------------------------------------
  #--------------------------------------------------------

  # ALERT, NOTICE, UPDATE send to all immediately with that level
  # TODO: USE environment variable for announcement levels (csv array to regex)
  robot.respond /(ALERT|NOTICE|UPDATE|SOCIAL)/, (msg) ->
    if announcement = new Announcement(msg) or false
      announcement.sendTo 'all' # TODO: replace with query match "<type> to <target> <message>"
    else
      msg.reply "An error stopped me from creating that announcement."

  # NEW starts dialog to gather parameters
  robot.respond /(NEW)(.*)/, (msg) ->

    # Determine alert type if passed in command (defautls to NOTICE)
    match2 = msg.match[2].trim()
    if match2 and match2.length and ['ALERT','NOTICE','UPDATE','SOCIAL'].indexOf(msg.match[2].trim()) isnt -1
      type = match2
    else
      type = "NOTICE"

    # Start dialog expecting response as the announcement message
    dialog = switchBoard.startDialog msg
    msg.reply "OK, I'll create a #{ type } from your next message.\nReply with the message you'd like to send (or `cancel` within 30 seconds)."

    # Cancel announcement and dialog if told to
    dialog.addChoice /cancel/i, (msg2) ->
      msg2.reply "OK, announcement cancelled."
      dialog.dialogTimeout = null
      robot.logger.info "NEW #{ type } announcement cancelled."

    # Capture any message that has at least one non-space character.
    dialog.addChoice /^(?!\s*$).+/, (msg2) ->
      robot.logger.info "NEW #{ type } announcement received."
      # NB: Pass whole of message as text or announcement will try crop the matching word (which is everything)
      text = stripRobotName msg2.message.text
      if announcement = new Announcement(msg2, type, text) or false
        announcement.sendTo 'all'
      else
        msg2.reply "An error stopped me from creating that announcement."

    # Debug promise if nothing comes back
    dialog.dialogTimeout = (msg) ->
      robot.logger.debug "Announcement conversation timed out"
      msg.reply "Confirmation window expired. Start again with `NEW` command."

  return @ # end robot exports
