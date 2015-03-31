require 'slack-api'

class SlackNotification
  def initialize(stage, deploy)
    @stage, @deploy = stage, deploy
    @project = @stage.project
    @user = @deploy.user
  end

  def deliver
    #subject = "[#{@project.name}] #{@deploy.summary}"
    #url = url_helpers.project_deploy_url(@project, @deploy)

    Slack.chat_postMessage(
      token: ENV['SLACK_TOKEN'],
      channel: @stage.slack_channel,
      text: content,
      parse: "full")

  rescue Slack::Error => e
    # Some problem communicating to slack server
    puts e
  end

  private

  def content
    @content ||= SlackNotificationRenderer.render(@deploy)
  end

  def url_helpers
    Rails.application.routes.url_helpers
  end
end
