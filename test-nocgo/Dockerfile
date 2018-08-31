ARG PACKAGE=test-nocgo
ARG IMAGE_NAME
FROM ${IMAGE_NAME} as builder

FROM scratch
COPY --from=builder /app /app
ENTRYPOINT [ "/app" ]
