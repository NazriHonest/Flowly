package com.example.flowly

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters

class SmsInboxDrainWorker(
    context: Context,
    parameters: WorkerParameters,
) : Worker(context, parameters) {
    companion object {
        private const val TAG = "FlowlySMS"
    }

    override fun doWork(): Result {
        if (!AutomaticDetectionStore.isEnabled(applicationContext)) {
            return Result.success()
        }
        if (!AutomaticDetectionStore.hasRequiredPermissions(applicationContext)) {
            AutomaticDetectionStore.setEnabled(applicationContext, false)
            return Result.success()
        }

        Log.d(TAG, "background_processing_started")
        val signalSequence = AutomaticDetectionStore.signalSequence(applicationContext)
        val checkpoint = AutomaticDetectionStore.checkpoint(applicationContext)
        val rows = try {
            SmsInboxReader.read(applicationContext, checkpoint)
        } catch (_: Throwable) {
            Log.d(TAG, "retry_scheduled")
            return Result.retry()
        }
        Log.d(TAG, "inbox_rows_found=${rows.size}")

        if (rows.isEmpty()) {
            if (AutomaticDetectionStore.hasPendingSignal(applicationContext)) {
                Log.d(TAG, "retry_scheduled")
                return Result.retry()
            }
            AutomaticDetectionStore.acknowledgeSignal(applicationContext, signalSequence)
            Log.d(TAG, "background_processing_completed")
            return Result.success()
        }

        val outcome = SmsBackgroundEngine.process(applicationContext, rows)
        if (outcome == null) {
            Log.d(TAG, "retry_scheduled")
            return Result.retry()
        }

        if (outcome.acknowledgedId != null && outcome.acknowledgedAt != null) {
            AutomaticDetectionStore.acknowledge(
                applicationContext,
                outcome.acknowledgedId,
                outcome.acknowledgedAt,
            )
            Log.d(TAG, "cursor_advanced")
        }
        if (outcome.changed) {
            Handler(Looper.getMainLooper()).post {
                SmsEventBridge.publishDatabaseChanged()
            }
        }
        if (outcome.retry || rows.size == SmsInboxReader.BATCH_SIZE) {
            Log.d(TAG, "retry_scheduled")
            return Result.retry()
        }

        AutomaticDetectionStore.acknowledgeSignal(applicationContext, signalSequence)
        Log.d(TAG, "background_processing_completed")
        return Result.success()
    }
}
