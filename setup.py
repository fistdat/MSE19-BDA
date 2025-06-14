from setuptools import find_packages, setup

setup(
    name="dagster_dbt_data_vault",
    packages=find_packages(exclude=["dagster_dbt_data_vault_tests"]),
    install_requires=[
        "dagster==1.6.6",
        "dagster-cloud==1.6.6", 
        "dagster-dbt==0.22.6",
        "dagster-aws==0.22.6",
        "dbt-trino==1.7.1",
        "Jinja2==3.1.6",
        "pyyaml==6.0.2",
        "trino==0.330.0",
        "pydantic==2.11.6",
    ],
    extras_require={
        "dev": [
            "dagster-webserver==1.6.6",
            "pytest==8.4.0",
            "faker==30.10.0"
        ]
    },
)
