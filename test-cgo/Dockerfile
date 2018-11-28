ARG REPOSITORY=test-cgo
ARG IMAGE_NAME
ARG CGO_ENABLED=1
FROM ${IMAGE_NAME} as builder

FROM scratch
COPY --from=builder /app /app
ENTRYPOINT [ "/app" ]
