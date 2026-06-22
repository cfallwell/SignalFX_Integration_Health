resource "signalfx_detector" "detector" {
  name        = var.name
  description = var.description
  tags        = var.tags
  teams       = var.teams

  authorized_writer_teams = var.authorized_writer_teams
  authorized_writer_users = var.authorized_writer_users

  timezone     = var.time_zone
  max_delay    = var.max_delay
  min_delay    = var.min_delay
  program_text = var.signalflow_file_path

  # Rule 1: AWS integration auth failure
  rule {
    detect_label          = "AWS integration auth failure"
    severity              = var.rule_severities["AWS integration auth failure"]
    parameterized_body    = var.rule_messages["AWS integration auth failure"].body
    parameterized_subject = var.rule_messages["AWS integration auth failure"].subject
    disabled              = false

    notifications = lookup(
      var.rule_notifications,
      "AWS integration auth failure",
      []
    )
  }

  # Rule 2: AWS integration disabled
  rule {
    detect_label          = "AWS integration disabled"
    severity              = var.rule_severities["AWS integration disabled"]
    parameterized_body    = var.rule_messages["AWS integration disabled"].body
    parameterized_subject = var.rule_messages["AWS integration disabled"].subject
    disabled              = false

    notifications = lookup(
      var.rule_notifications,
      "AWS integration disabled",
      []
    )
  }

  # Rule 3: AWS integration stale / no datapoints
  rule {
    detect_label          = "AWS integration stale / no datapoints"
    severity              = var.rule_severities["AWS integration stale / no datapoints"]
    parameterized_body    = var.rule_messages["AWS integration stale / no datapoints"].body
    parameterized_subject = var.rule_messages["AWS integration stale / no datapoints"].subject
    disabled              = false

    notifications = lookup(
      var.rule_notifications,
      "AWS integration stale / no datapoints",
      []
    )
  }

  # Rule 4: AWS API exceptions - org scoped
  rule {
    detect_label          = "AWS API exceptions - org scoped"
    severity              = var.rule_severities["AWS API exceptions - org scoped"]
    parameterized_body    = var.rule_messages["AWS API exceptions - org scoped"].body
    parameterized_subject = var.rule_messages["AWS API exceptions - org scoped"].subject
    disabled              = false

    notifications = lookup(
      var.rule_notifications,
      "AWS API exceptions - org scoped",
      []
    )
  }

  # Rule 5: Logs stopped by token
  rule {
    detect_label          = "Logs stopped by token"
    severity              = var.rule_severities["Logs stopped by token"]
    parameterized_body    = var.rule_messages["Logs stopped by token"].body
    parameterized_subject = var.rule_messages["Logs stopped by token"].subject
    disabled              = false

    notifications = lookup(
      var.rule_notifications,
      "Logs stopped by token",
      []
    )
  }
}
