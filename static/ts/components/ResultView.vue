<template>
    <div>
        <label class="DataLabel">{{ value.name }}</label>
        <span class="DataValue">
            <!-- Auto-reflow to next line due to div -->
            <template v-if="isArrResult">
                <ul class="list-group">
                    <Result-View v-for="val in value" v-bind:value="val"></Result-View>
                </ul>
            </template>
            <template v-else>
                {{ asStr }}
            </template>
        </span>
    </div>


</template>

<script lang="ts">
import Vue from "vue";
import * as util from '../utils';
import * as constants from '../constants';

export default Vue.component('ResultView', {
    name: 'ResultView',
    props: ['value'],
    computed: {
        isArrResult: function() : boolean {
            return util.detectType(this.value) == constants.TYPE_ARRAY;
        },
        valType: function() : string {
            return util.detectType(this.value);
        },
        asStr: function() : string {
            return util.formatValue(this.value);
        }
    }
});
</script>

<style>
</style>
