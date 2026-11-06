# fullmoon iOS
![fullmoon iOS](https://fullmoon.app/images/app.png)

[fullmoon](https://fullmoon.app) is an iOS app to chat with local large language models that’s optimized for Apple silicon and works on iPhone, iPad, and Mac. your chat history is saved locally, and you can customize the appearance of the app.

## supported models

On iOS, the app uses the fixed Llama 3.2 1B Instruct 4-bit model. Settings displays its download and loading status without a model picker. The model catalog remains available on the other supported platforms.

- [x] [Llama 3.2 1B](https://huggingface.co/mlx-community/Llama-3.2-1B-Instruct-4bit)
- [x] [Llama 3.2 3B](https://huggingface.co/mlx-community/Llama-3.2-3B-Instruct-4bit)
- [x] [DeepSeek-R1-Distill-Qwen-1.5B-4bit](https://huggingface.co/mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit)

## credits
fullmoon is made possible by [MLX Swift](https://github.com/ml-explore/mlx-swift) from Apple. [MLX](https://github.com/ml-explore/mlx) is an array framework for machine learning research on Apple silicon.

## model status tests

The state and local-cache checks can run without MLX, a model download, or an Xcode test target:

```sh
swiftc fullmoon/Models/ModelStatus.swift tests/ModelStatusTests.swift -o /tmp/fullmoon-model-status-tests
/tmp/fullmoon-model-status-tests
```

These tests cover monotonic download progress, the transition from download completion to loading, late callbacks after success or failure, retry availability, and missing, malformed, truncated, and sharded model caches. They do not exercise MLX inference or replace an iOS build and device test.
