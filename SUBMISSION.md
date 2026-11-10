# Submission

Fork URL: <!-- paste the URL of your fork here -->

## Files to commit

- [ ] `notes.md` with your commands and what you saw (optional)

## Questions

Answer in your own words. Where a question asks for output, paste it in a code block.

### Q1. Paste the command and the (redacted) output that fetched the role credentials from `169.254.169.254` with IMDSv1. Which three values did you get and what could you do with them from your laptop?

**Your answer:**

<!-- replace this line with your answer -->

### Q2. Paste the `aws ec2 modify-instance-metadata-options` you used and the failed request afterwards. What is different about an IMDSv2 request, and why does a simple SSRF bug usually fail against it?

**Your answer:**

<!-- replace this line with your answer -->

### Q3. What does `HttpPutResponseHopLimit 1` change for a container running on the instance? Where would you set 2 on purpose?

**Your answer:**

<!-- replace this line with your answer -->

### Q4. Show the role's permission policy. What could an attacker do with the stolen credentials before you fixed it and after?

**Your answer:**

<!-- replace this line with your answer -->

### Q5. The security group allowed SSH from your IP only. Why is that better than `0.0.0.0/0`, and what do you do when your IP changes?

**Your answer:**

<!-- replace this line with your answer -->

### Q6. Paste the output of `./verify.sh`. It must end with **ALL CHECKS PASSED**.

**Your answer:**

<!-- replace this line with your answer -->

### Q7. **Tear down.** Paste the output of `./verify-teardown.sh`. It must end with **TEARDOWN VERIFIED**.

**Your answer:**

<!-- replace this line with your answer -->
