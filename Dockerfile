ARG VERSION=latest
FrOm ubuntu:${VERSION} AS mika_base



FROM mika_base AS mika_dev_base
RUN echo "Development Base Image"

FROM mika_base AS mika_qa_base
RUN echo "QA Base Image"

docker pull dhi.io/pytorch:2.9-cuda13.0-cudnn9-debian13-dev