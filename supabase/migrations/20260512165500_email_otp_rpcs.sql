CREATE OR REPLACE FUNCTION generate_email_otp(user_id UUID, user_email TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  new_otp TEXT;
BEGIN
  -- Generate a 6-digit random OTP
  new_otp := lpad(floor(random() * 1000000)::text, 6, '0');
  
  -- Update the user's profile with the OTP and timestamp
  UPDATE profiles
  SET 
    email = user_email,
    current_email_otp = new_otp,
    last_email_otp_sent_at = NOW(),
    email_verification_attempts = 0,
    email_verified = FALSE
  WHERE id = user_id;

  -- In a real production system, you would insert into an email queue or call an external service (like SendGrid or Supabase Edge Function) here to actually send the email.
  -- For this implementation, the OTP is stored securely in the database.
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION verify_email_otp(user_id UUID, submitted_otp TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  stored_otp TEXT;
  otp_time TIMESTAMPTZ;
  attempts INT;
BEGIN
  SELECT current_email_otp, last_email_otp_sent_at, email_verification_attempts
  INTO stored_otp, otp_time, attempts
  FROM profiles
  WHERE id = user_id;

  -- Check if OTP exists
  IF stored_otp IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Check expiry (10 minutes)
  IF NOW() > otp_time + INTERVAL '10 minutes' THEN
    RETURN FALSE;
  END IF;

  -- Check max attempts (e.g., 5)
  IF attempts >= 5 THEN
    RETURN FALSE;
  END IF;

  -- Verify OTP
  IF stored_otp = submitted_otp THEN
    -- Success
    UPDATE profiles
    SET 
      email_verified = TRUE,
      email_verified_at = NOW(),
      current_email_otp = NULL
    WHERE id = user_id;
    RETURN TRUE;
  ELSE
    -- Increment attempts
    UPDATE profiles
    SET email_verification_attempts = attempts + 1
    WHERE id = user_id;
    RETURN FALSE;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
