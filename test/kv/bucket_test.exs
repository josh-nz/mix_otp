defmodule KV.BucketTest do
  use ExUnit.Case, async: true

  setup do
    bucket = start_supervised!(KV.Bucket)
    %{bucket: bucket}
  end

  test "stores values by key", %{bucket: bucket} do
    assert KV.Bucket.get(bucket, "milk") == nil

    KV.Bucket.put(bucket, "milk", 3)
    assert KV.Bucket.get(bucket, "milk") == 3
  end

  test "deletes values by key, returning value", %{bucket: bucket} do
    KV.Bucket.put(bucket, "milk", 3)
    value = KV.Bucket.delete(bucket, "milk")
    assert value == 3

    is_gone = KV.Bucket.get(bucket, "milk")
    assert is_gone == nil
  end

  test "are temporary workers" do
    assert Supervisor.child_spec(KV.Bucket, []).restart == :temporary
  end
end
