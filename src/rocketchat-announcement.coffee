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
#   TODO: Add announcement levels (critical, informative, incidental) so robot brain can remember user preferences
#         e.g. hubot don't send me anything below <level>
#   TODO: Add report command to reply with announcement analytics
#         e.g. hubot announcement report 19
#           <message> (excerpt) was sent to 245 users last Tuesday at 4:12pm
#           122 received it successfully. 41 have been online, but didn't open announcements.
#           82 users have not been online since it was sent.

# Use hubot conversation to branch inputs
Conversation = require 'hubot-conversation'

module.exports = (robot) ->
  robotName = robot.alias or robot.name
  switchBoard = new Conversation robot

  # Get robot brain collection pointer when DB merged in
  robot.brain.on 'loaded', =>
    if robot.brain.get('announcements') is null
      robot.brain.set 'announcements', []

  # Get announcement text from trigger message
  # Uses text inside quotes TODO: Use whole copy of msg.envelope
  getAnnouncementText = (msg) ->
    captureQuote = msg.match[1].trim().match(/(")(?:(?=(\\?))\2.)*?\1/)[0] # match quoted segment
    captureQuote = if captureQuote.length > 0 then captureQuote.substring(1, captureQuote.length - 1) else null # trim quotes
    unless captureQuote is null
      return captureQuote
    else
      robot.logger.error "Announce command received with no quoted text to use as message."
      msg.send "Sorry, you need to give the announcement text as a quote. e.g. announce \"Hello World!\""
      return false

  # Get the users for the specified target group
  getTargetUsers = (target) ->
    switch target
      when 'all'
        botRequest = robot.adapter.callMethod('botRequest', 'allIDs')
    return botRequest

  # Create, send and save announcement
  sendAnnouncement = (text, users, msg) ->
    unless text is "" or users.length < 1 or msg is null
      robot.logger.info "Sending \"#{ announcement.text }\" to #{ users.length } users."

      # Save announcement in brain and persist
      announcement = {
        text: text,
        users: users,
        source: msg.envelope.user,
        messagess: []
      }
      robot.brain.set 'announcements', announcement
      robot.brain.save()
      console.log robot.brain.data

      console.log "-------------------+\n #{ msg.envelope } \n+-------------------"

      # Send to each user and store sent message IDs
      for user in users
        directMessage = redirectEnvelope msg, user
        directMessage.then (dmsg)
          announcement.messages.push dmsg

          console.log "-------------------+\n #{ announcement.messages } \n+-------------------"

    else
      robot.logger.error "Announce method received insufficient parameters."

  # Redirect a message as DM to another user
  redirectEnvelope = (msg, user) ->
    envelope = msg.envelope
    directRoom = getDirectMessageRoomId user.name
    directRoom.then (rid) ->
      envelope.rid = rid
      directMessage = robot.sendDirect envelope

  # Start with command and message
  robot.respond /announce (.*)/i, (msg) ->
    announcementText = getAnnouncementText msg
    dialog = switchBoard.startDialog msg
    target = 'all' # TODO: replace with query match "announce "<message>" to <target>"

    # Get target group users before responding
    getTargetUsers(target).then (users) ->

      if (users.length > 0)

        # If there's users to announce to
        # get confirmation then send
        msg.reply "Send \"#{ announcementText }\" to #{ users.length } users?\n\nSay `#{ robotName } send` to confirm (within 30 seconds) or `#{ robotName } cancel` to stop."

        # On confirmation or cancel
        dialog.addChoice /send/i, (msg) ->
          console.log "------SENDING------"
          sendAnnouncement announcementText, users, msg

        dialog.addChoice /cancel/i, (msg) ->
          console.log "------CANCEL------"
          msg.reply "OK, announcement cancelled."
          dialog.dialogTimeout = null

      else

        # No results
        robot.logger.error "Bot helper request returned 0 users"
        msg.reply "There's been an error. I can't get target users for the announcement."
        dialog.dialogTimeout = null

      return

    .catch (e) ->
      robot.logger.error "Bot helper request returned error: #{ error }"
      msg.reply "There's been an error. I can't get query the app to find users."
      dialog.dialogTimeout = null
      return

    # Debug promise if nothing comes back
    dialog.dialogTimeout = (msg) ->
      robot.logger.debug "Announcement conversation timed out"
      msg.reply "Confirmation window expired. Start again with `announce` command."
      return

  return @ # end robot exports
