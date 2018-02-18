<template>
    <div class="CellErrors">
        <div class="alert alert-danger CellError" role="alert" v-for="error in cell.errors">
            <i class="fas fa-exclamation-triangle"></i> &nbsp; {{error}}
        </div>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import {Value} from "../engine/engine";

export default Vue.component('CellErrors', {
    name: 'CellErrors',
    props: {
        'cell': {type: Value}
    },
});
</script>

<style>
</style>
