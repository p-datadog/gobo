from locust import HttpUser, task, between

# requests.Session has no default timeout — it must be passed per-request.
# self.client.timeout is ignored; only the timeout= kwarg works.
# https://docs.locust.io/en/stable/api.html
# https://github.com/orgs/locustio/discussions/3046
TIMEOUT = (5, 15)  # (connect timeout, read timeout) in seconds


class GoboUser(HttpUser):
    wait_time = between(0.01, 0.05)

    @task(3)
    def index(self):
        self.client.get("/", timeout=TIMEOUT)

    @task(3)
    def stdlib_probe(self):
        self.client.get("/debugger_test/stdlib_probe", timeout=TIMEOUT)

    @task(1)
    def help(self):
        self.client.get("/help", timeout=TIMEOUT)

    @task(1)
    def about(self):
        self.client.get("/about", timeout=TIMEOUT)
