from locust import HttpUser, task, between


class GoboUser(HttpUser):
    wait_time = between(0.01, 0.05)

    @task(3)
    def index(self):
        self.client.get("/")

    @task(3)
    def stdlib_probe(self):
        self.client.get("/debugger_test/stdlib_probe")

    @task(1)
    def help(self):
        self.client.get("/help")

    @task(1)
    def about(self):
        self.client.get("/about")
