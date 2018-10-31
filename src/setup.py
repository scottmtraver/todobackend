from setuptools import setup, find_packages

setup(
    name = "todobackend",
    version = "0.1.0",
    description = "Todobackend REST service API",
    packages = find_packages(),
    include_package_data = True,
    scripts = ["manage.py"],
    install_requires = [
        "astroid>=2.0.4",
        "Django>=2.1.2",
        "django-cors-headers>=2.4.0",
        "djangorestframework>=3.9.0",
        "isort>=4.3.4",
        "lazy-object-proxy>=1.3.1",
        "mccabe>=0.6.1",
        "mysqlclient>=1.3.13",
        "pylint>=2.1.1",
        "pylint-django>=2.0.2",
        "pylint-plugin-utils>=0.4",
        "pytz>=2018.5",
        "six>=1.11.0",
        "wrapt>=1.10.11",
        "uWSGI>=2.0.17.1"],
    extras_require = {
        "test": [
            "colorama>=0.4.0",
            "coverage>=4.5.1",
            "django-nose>=1.4.6",
            "nose>=1.3.7",
            "pinocchio>=0.4.2"
        ]
    }
)
