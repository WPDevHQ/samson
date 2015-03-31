require 'slack'

module SamsonSlack
  class Engine < Rails::Engine
  end
end

Samson::Hooks.callback :stage_defined do
  Stage.class_eval do
    has_many :slack_channels
    accepts_nested_attributes_for :slack_channels, allow_destroy: true, reject_if: :no_channel_name?
    validate :channel_exists?
    before_save :update_channel_id

    def send_slack_notifications?
      slack_channels.any?
    end

    def no_channel_name?(slack_attrs)
      slack_attrs['name'].blank?
    end

    def update_channel_id
      self.slack_channels.first.channel_id = channel_for(slack_channels.first.name)['id']
    end

    def channel_exists?
      errors.add(:slack_channels_name, "was not found") unless channel_for(slack_channels.first.name)
    end

    def channel_for(name)
      response = Slack.channels_list(exlcude_archived: 1)
      response['channels'].select { |c| c['name'] == name }.first
    end
  end
end

Samson::Hooks.view :stage_form, "samson_slack/fields"

Samson::Hooks.callback :stage_clone do |old_stage, new_stage|
  new_stage.slack_channels.build(old_stage.slack_channels.map(&:attributes))
end

Samson::Hooks.callback :stage_permitted_params do
  {slack_channels_attributes: [:id, :name, :token, :_destroy]}
end

notify = -> (stage, deploy, _buddy) do
  if stage.send_slack_notifications?
    SlackNotification.new(stage, deploy).deliver
  end
end

Samson::Hooks.callback :before_deploy, &notify
Samson::Hooks.callback :after_deploy, &notify
