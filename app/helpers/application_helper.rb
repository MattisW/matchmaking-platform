module ApplicationHelper
  def time_options_15min
    (0..23).flat_map do |hour|
      [0, 15, 30, 45].map do |min|
        time = sprintf("%02d:%02d", hour, min)
        [time, time]
      end
    end
  end
end
