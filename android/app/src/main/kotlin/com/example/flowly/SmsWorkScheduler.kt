package com.example.flowly

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequest
import androidx.work.Operation
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

object SmsWorkScheduler {
    const val UNIQUE_WORK_NAME = "flowly_sms_inbox_drain"

    fun enqueue(context: Context): Operation {
        val request = OneTimeWorkRequest.Builder(SmsInboxDrainWorker::class.java)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 10, TimeUnit.SECONDS)
            .addTag(UNIQUE_WORK_NAME)
            .build()
        return WorkManager.getInstance(context).beginUniqueWork(
            UNIQUE_WORK_NAME,
            ExistingWorkPolicy.APPEND_OR_REPLACE,
            request,
        ).enqueue()
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(UNIQUE_WORK_NAME)
    }
}
