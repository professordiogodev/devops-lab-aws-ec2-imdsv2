#!/usr/bin/env python3
import json, os, re, subprocess, sys, urllib.request
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
os.chdir(ROOT)
passed = failed = 0


def check(desc, ok, hint=""):
    global passed, failed
    if ok:
        passed += 1; print("PASS  " + desc)
    else:
        failed += 1; print("FAIL  " + desc + (("   -> " + hint) if hint else ""))


def aws(*a):
    try:
        return json.loads(subprocess.check_output(("aws",) + a + ("--output", "json"), stderr=subprocess.DEVNULL, timeout=60) or "null")
    except Exception:
        return None


def sh(c):
    r = subprocess.run(c, shell=True, capture_output=True, text=True)
    return r.returncode, r.stdout


print("== The server ==")
insts = []
for r in (aws("ec2", "describe-instances", "--filters", "Name=tag:lab,Values=aws-ec2-imdsv2", "Name=instance-state-name,Values=running") or {}).get("Reservations", []):
    insts += r["Instances"]
check("one running server tagged lab=aws-ec2-imdsv2", len(insts) == 1, "./setup.sh")
if not insts:
    print("\nNothing else can be checked.\n%d check(s) failed, %d passed" % (failed, passed)); sys.exit(1)
i = insts[0]
md = i["MetadataOptions"]
check("IMDSv2 is REQUIRED (HttpTokens = required)", md["HttpTokens"] == "required", "aws ec2 modify-instance-metadata-options")
check("the hop limit is 1 (a container or a proxy one hop away cannot reach the metadata service)", md["HttpPutResponseHopLimit"] == 1)
check("the metadata service is still enabled (the role must keep working)", md["HttpEndpoint"] == "enabled")
check("a role is attached through an instance profile", "IamInstanceProfile" in i)
role = "clippy-imds-role"
att = (aws("iam", "list-attached-role-policies", "--role-name", role) or {}).get("AttachedPolicies", [])
check("the role has no AWS managed policy (the broad AmazonS3ReadOnlyAccess is gone)", not att, ", ".join(p["PolicyName"] for p in att))
docs = [(aws("iam", "get-role-policy", "--role-name", role, "--policy-name", n) or {}).get("PolicyDocument", {"Statement": []}) for n in (aws("iam", "list-role-policies", "--role-name", role) or {}).get("PolicyNames", [])]
def sts(d):
    s = d["Statement"]; return s if isinstance(s, list) else [s]
acts = {a for d in docs for s in sts(d) if s["Effect"] == "Allow" for a in ([s["Action"]] if isinstance(s["Action"], str) else s["Action"])}
res = {a for d in docs for s in sts(d) if s["Effect"] == "Allow" for a in ([s["Resource"]] if isinstance(s["Resource"], str) else s["Resource"])}
check("any permission it still has is narrow: no '*' in actions or resources (an empty policy is fine)", not any("*" in a for a in acts) and not any(r == "*" for r in res), "actions %s, resources %s" % (sorted(acts), sorted(res)))
sgs = [g["GroupId"] for g in i.get("SecurityGroups", [])]
rules = (aws("ec2", "describe-security-group-rules", "--filters", "Name=group-id,Values=" + ",".join(sgs)) or {}).get("SecurityGroupRules", [])
ing = [r for r in rules if not r["IsEgress"]]
check("SSH (22) is allowed from one /32 address only", [r for r in ing if r["FromPort"] == 22] and all(r.get("CidrIpv4", "").endswith("/32") for r in ing if r["FromPort"] == 22) and len([r for r in ing if r["FromPort"] == 22]) == 1)
check("only ports 22 and 80 are open", all(r["FromPort"] in (22, 80) for r in ing))

print("== The attack, from inside the server ==")
ip = i.get("PublicIpAddress")
ssh = "ssh -i clippy-imds.pem -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o LogLevel=ERROR ubuntu@%s " % ip
if os.path.exists("clippy-imds.pem") and ip:
    rc, out = sh(ssh + "'curl -s -o /dev/null -w %{http_code} http://169.254.169.254/latest/meta-data/iam/security-credentials/'")
    check("IMDSv1 (a plain GET, the way an SSRF bug makes it) is refused with 401", out.strip() == "401", "got %r" % out.strip())
    rc, out = sh(ssh + "'T=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H \"X-aws-ec2-metadata-token-ttl-seconds: 60\"); curl -s -o /dev/null -w %{http_code} -H \"X-aws-ec2-metadata-token: $T\" http://169.254.169.254/latest/meta-data/iam/security-credentials/'")
    check("IMDSv2 (PUT for a token, then GET with the token) still works: 200", out.strip() == "200", "got %r" % out.strip())
else:
    check("the key clippy-imds.pem and a public IP are here to test from inside", False, "did you run teardown? the server is gone")
try:
    code = urllib.request.urlopen("http://%s/healthz" % ip, timeout=10).status
except Exception:
    code = 0
check("Clippy still answers on port 80", code == 200)
print()
print(("ALL CHECKS PASSED (%d/%d)" % (passed, passed)) if failed == 0 else ("%d check(s) failed, %d passed" % (failed, passed)))
sys.exit(1 if failed else 0)
