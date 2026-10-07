# Optional dedicated worker; does not run until explicitly started.
loop do
  result = CanvasSyncRunner.run_one
  puts({ job_id: result.id, status: result.status, attempts: result.attempts }.to_json) if result
  sleep(result ? 1 : 5)
end
