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
#   TODO: Add announcement levels (critical "ALERT", informative "NOTICE", incidental "UPDATE") so robot brain can remember user preferences
#         e.g. hubot don't send me anything below <level>
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

  # ALERT, NOTICE, UPDATE send to all immediately with that level
  robot.respond /(ALERT|NOTICE|UPDATE)/, (msg) ->
    announcement = new Announcement msg
    announcement.sendTo 'all' # TODO: replace with query match "announce "<message>" to <target>"

  # NEW starts dialog to gather parameters
  robot.respond /NEW/, (msg) ->
    dialog = switchBoard.startDialog msg
    target = 'all' # TODO: replace with query match "announce "<message>" to <target>"
    msg.reply "OK, I will create an announcement from your next message. What would you like to say?"

    dialog.addChoice /cancel/i, (msg) ->
      msg.reply "OK, announcement cancelled."
      dialog.dialogTimeout = null
      robot.logger.info "Announcement cancelled."

    dialog.receive (msg) ->
      robot.logger.info "Announcement received."

    # Debug promise if nothing comes back
    dialog.dialogTimeout = (msg) ->
      robot.logger.debug "Announcement conversation timed out"
      msg.reply "Confirmation window expired. Start again with `announce` command."
      return

    return @ # end robot exports

# Announcement object instantiated from a given message
class Announcement

  # Set attributes and remove command trigger from message text
  constructor: (@msg) ->
    @adapter = @msg.robot.adapter
    @logger = @msg.robot.logger
    @original = @msg.envelope
    @DMs = []
    @level = @msg.match[1]
    @text = @original.message.text = @original.message.text.substring @msg.match[0].length
    @text = @text.trim()
    if @text is ""
      @logger.error "No text in announcement after trim."
      @msg.reply "Sorry, there's no text content in that message. Please try again."
    else
      @logger.debug "Creating #{ @level } announcement with message \"#{ @text }\""

  # Get the users for the specified target group (defaults to all)
  setTarget: (@target) ->
    switch @target
      when 'online' then botRequest = @adapter.callMethod('botRequest', 'onlineIDs')
      else botRequest = @adapter.callMethod('botRequest', 'allIDs')

    botRequest.then (result) =>
      @users = result
      @logger.info "Announcement targeted at #{ @users.length } users."
      if @users.length < 1
        throw 'No users'
    .catch (error) =>
      @logger.error "User request returned error: #{ error }"
      msg.reply "There's been an error. I can't get target users for the announcement."
    return botRequest

  # Get addresses for each user's DM room
  prepareRooms: () ->
    @logger.debug "Announcement addrressed to #{ @users.length } users."
    return Q.all _.map @users, (user) => @addressDM user
    .catch (error) =>
      @logger.error "Error addressing direct messages: #{ JSON.stringify error }"

  # Re-address original envolope as DM to given user
  addressDM: (user) ->
    @logger.debug "Fetching DM Room ID for #{ user.name }"
    roomRequest = @adapter.chatdriver.getDirectMessageRoomId user.name
    roomRequest.then (result) =>
      @DMs.push {
        "room": result.rid,
        "user": user
      }
      @logger.debug "Addressing announcement DM to #{ result.rid } (#{ user.name })"
    .catch (error) =>
      @logger.error "Error getting DM Room ID for #{ user.name }: #{ JSON.stringify error }"
    return roomRequest

  # Send DM for all target users
  sendDMs: () ->
    @logger.debug "Sending #{ @DMs.length } direct messages..."
    return Q.all _.map @DMs, (DM) => @sendToRoom DM.room
    .catch (error) =>
      @logger.error "Error sending direct messages: #{ JSON.stringify error }"

  # Send announcement text to room
  sendToRoom: (room) ->
    @logger.debug "...to #{ room }"
    sendingDM = Q.fcall () =>
      @adapter.chatdriver.sendMessageByRoomId @text, room
    sendingDM.then (result) =>
      @logger.debug "Sent DM: #{ result }"
    .catch (error) =>
      @logger.error "Error sending DM: #{ error }"
    return sendingDM

  # Save announcement in robot brain and persist
  save: () ->
    # @msg.robot.brain.set 'announcements', @Announcement
    # @msg.robot.brain.save()

  # Send announcement as DM to all in target group
  sendTo: (target) ->
    # TODO: take target from msg parameters
    return @setTarget(target)
    .then () =>
      @prepareRooms()
    .then () =>
      @sendDMs()
