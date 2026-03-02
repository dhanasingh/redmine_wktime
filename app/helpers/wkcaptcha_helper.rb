# Reusable CAPTCHA helper for controllers
# Usage: include WkcaptchaHelper in any controller, then:
#   - Call generate_captcha in the action that renders the form
#   - Call valid_captcha?(params[:captcha_answer]) to validate user input

module WkcaptchaHelper

  # Generate a simple math CAPTCHA and store answer in session
  def generate_captcha
    @captcha_num1 = (1..19).map { |n| n * 5 }.sample  # multiples of 5 up to 95
    @captcha_num2 = (1..4).map { |n| n * 5 }.sample   # multiples of 5 up to 20
    @captcha_op = ['+', '-'].sample

    if @captcha_op == '+'
      session[:captcha_answer] = @captcha_num1 + @captcha_num2
    else
      session[:captcha_answer] = @captcha_num1 - @captcha_num2
    end

    question = "What is #{@captcha_num1} #{@captcha_op} #{@captcha_num2}?"
    @captcha_image = generate_captcha_svg(question)
  end

  # Validate user's captcha answer against session
  def valid_captcha?(answer)
    answer.to_s.strip.present? && answer.to_s.strip.to_i == session[:captcha_answer]
  end

  private

  def generate_captcha_svg(text)
    require 'base64'
    width = 220
    height = 60

    # Generate random noise elements
    noise_lines = 5.times.map do
      x1 = rand(0..width)
      y1 = rand(0..height)
      x2 = rand(0..width)
      y2 = rand(0..height)
      color = ["#94a3b8", "#cbd5e1", "#64748b", "#a1a1aa"].sample
      %(<line x1="#{x1}" y1="#{y1}" x2="#{x2}" y2="#{y2}" stroke="#{color}" stroke-width="#{rand(1..2)}" opacity="#{(rand(3..7) / 10.0)}"/>)
    end.join("\n      ")

    noise_dots = 20.times.map do
      cx = rand(0..width)
      cy = rand(0..height)
      r = rand(1..3)
      color = ["#94a3b8", "#cbd5e1", "#475569"].sample
      %(<circle cx="#{cx}" cy="#{cy}" r="#{r}" fill="#{color}" opacity="#{(rand(2..5) / 10.0)}"/>)
    end.join("\n      ")

    # Random slight rotation for text (-3 to +3 degrees)
    rotation = rand(-3..3)

    svg = <<~SVG
      <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="#f8fafc"/>
        #{noise_lines}
        #{noise_dots}
        <text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle"
              font-family="Arial, sans-serif" font-size="20" fill="#1e293b"
              font-weight="bold" transform="rotate(#{rotation}, #{width/2}, #{height/2})">#{text}</text>
        #{noise_lines}
      </svg>
    SVG
    "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}"
  end
end
