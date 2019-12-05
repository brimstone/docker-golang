ARG REPOSITORY=test-nocgo
ARG IMAGE_NAME
FROM ${IMAGE_NAME}-onbuild as builder

FROM scratch
COPY --from=builder /app /app
ENTRYPOINT [ "/app" ]
