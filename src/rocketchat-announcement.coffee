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

  # Get user from Rocket.chat (outside class so it can be called directly)
  getUsers = () ->
    config = {
      userFields: { _id: 1, name: 1, username: 1, status: 1, emails: 1 },
      onlineQuery: { "status": { $ne: "offline" } },
      userQuery: { "roles": { $not: { $all: ["bot"] } } }
    }
    return Q.fcall () ->
      result = robot.adapter.callMethod 'users.find', config.userQuery, { fields: config.userFields }
      return result
    # this._onlineUsers = Meteor.users.find( { $and: [config.userQuery, config.onlineQuery] }, { fields: config.userFields } );
    # this._allUsers = Meteor.users.find( config.userQuery, { fields: config.userFields } );

  # Announcement object instantiated from a given message
  class Announcement

    constructor: (@msg) ->
      @original = @msg.envelope
      @level = @msg.match[0] # command text
      @DMs = []

      # Remove command from message text, validate then append source
      @text = @original.message.text = @original.message.text.substring @msg.match[0].length
      @text = "#{ @text.trim() }"
      if @text is ""
        robot.logger.error "No text in announcement after trim."
        @msg.reply "Sorry, there's no text content in that message. Please try again."
        return false
      else
        robot.logger.debug "Creating #{ @level } announcement with message '#{ @text }'"
      @text += "\nSent by @#{ @original.user.name }"

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
        robot.adapter.chatdriver.getDirectMessageRoomId user.name
        .then (result) =>
          robot.logger.debug "Addressing announcement DM to #{ result.rid } (#{ user.name })"
          @DMs.push { "room": result.rid, "user": user }
        .catch (error) =>
          robot.logger.error "Error getting DM Room ID for #{ user.name }: #{ JSON.stringify error }"

    # Send DM to all target users
    # NB: Q.fcall used because sendMessageByRoomId does not return a promise
    sendDMs: () ->
      robot.logger.debug "Sending #{ @DMs.length } direct messages..."
      return Q.all _.map @DMs, (DM) =>
        Q.fcall () => robot.adapter.chatdriver.sendMessageByRoomId @text, DM.room
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
  robot.respond /(ALERT|NOTICE|UPDATE)/, (msg) ->
    if announcement = new Announcement(msg) or false
      announcement.sendTo 'all' # TODO: replace with query match "announce "<message>" to <target>"
    else
      msg.reply "An error stopped me from creating that announcement."

  # Check WHO alert will go to for given target
  robot.respond /WHO/, (msg) ->
    getUsers().then (result) ->
      console.log result
      msg.reply JSON.stringify result.fetch()
    .catch (error) ->
      console.error error
      msg.reply "Couldn't get users"

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
